import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../crypto/merkle_engine.dart';
import '../crypto/worker_keys.dart';
import '../database/db_helper.dart';
import '../models/distribution_log.dart';
import '../models/resident.dart';
import '../models/scan_result.dart';
import '../models/sync_event.dart';
import 'sync_client.dart';

class PurokStats {
  final int purok;
  final int households;
  final int served;
  final int persons;
  final int vulnerable;
  const PurokStats({required this.purok, required this.households, required this.served, required this.persons, required this.vulnerable});
}

/// Central application state: offline verification pipeline, Merkle batch, and dual-sync.
class AppController extends ChangeNotifier {
  AppController({DbHelper? db, SyncClient? client, WorkerKeyStore? keyStore, String? workerId})
      : db = db ?? DbHelper.instance,
        client = client ?? SyncClient(),
        keyStore = keyStore ?? WorkerKeyStore(),
        workerId = workerId ?? const String.fromEnvironment('WORKER_ID', defaultValue: 'W-01');

  final DbHelper db;
  final SyncClient client;
  final WorkerKeyStore keyStore;
  final String workerId;

  /// A household may claim relief once per cooldown window.
  static const claimCooldown = Duration(hours: 72);
  static const healthInterval = Duration(seconds: 10);

  bool ready = false;
  String? initError;

  final Map<String, Resident> _byToken = {};
  final Map<String, Resident> _byId = {};
  List<Resident> get residents => _byId.values.toList(growable: false);
  Resident? residentById(String id) => _byId[id];

  RootSigner? _signer;
  String get publicKeyHex => _signer == null ? '' : toHex0x(_signer!.publicKey);

  final List<Uint8List> _pendingLeaves = [];
  final List<String> _pendingIds = [];
  int get pendingCount => _pendingIds.length;
  OfflineCheckpoint? checkpoint;
  int get treeHeight => MerkleEngine.treeHeight(_pendingIds.length);

  List<LogView> recentLogs = const [];
  List<SyncEvent> events = const [];
  Map<String, int> counts = const {};
  Set<String> servedRecently = const {};

  ScanResult? lastScan;
  final List<double> sessionLatencies = [];
  bool _scanBusy = false;

  DaemonHealth health = const DaemonHealth.unreachable('Not checked yet');
  bool get online => health.dualSyncActive;
  bool syncing = false;
  bool _registered = false;
  Timer? _healthTimer;

  // ------------------------------------------------------------- lifecycle

  Future<void> init() async {
    try {
      await db.seedResidentsIfEmpty();
      for (final r in await db.allResidents()) {
        _byToken[r.qrToken] = r;
        _byId[r.householdId] = r;
      }
      _signer = await keyStore.loadOrCreate(workerId);
      final leaves = await db.pendingLeaves();
      _pendingLeaves
        ..clear()
        ..addAll(leaves.map((l) => fromHex0x(l.leafHash)));
      _pendingIds
        ..clear()
        ..addAll(leaves.map((l) => l.transactionId));
      checkpoint = await db.loadCheckpoint();
      _registered = await db.getMeta(_registrationKey) == 'true';
      await refresh(notify: false);
      ready = true;
    } catch (e, st) {
      initError = '$e';
      debugPrintStack(stackTrace: st, label: 'LigtasLink init failed');
    }
    notifyListeners();
    if (ready) {
      _healthTimer = Timer.periodic(healthInterval, (_) => checkHealth());
      unawaited(checkHealth());
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _healthTimer?.cancel();
    super.dispose();
  }

  /// Health checks and syncs are async and may complete after disposal.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> refresh({bool notify = true}) async {
    recentLogs = await db.recentLogs();
    events = await db.syncEvents();
    counts = await db.counts();
    servedRecently = await db.householdsServedSince(_cutoffIso());
    if (notify) notifyListeners();
  }

  String _cutoffIso() => DateTime.now().toUtc().subtract(claimCooldown).toIso8601String();

  // ------------------------------------------------- offline verification

  /// Scan pipeline: O(1) token lookup → eligibility → insert log + frozen leaf →
  /// recompute R_offline → Ed25519 sign. Every stage is timed against the 100 ms budget.
  Future<ScanResult> verifyToken(String rawToken) async {
    final token = rawToken.trim().toUpperCase();
    if (_scanBusy) {
      return ScanResult(status: ScanStatus.error, token: token, message: 'Previous scan still processing.');
    }
    _scanBusy = true;
    final sw = Stopwatch()..start();
    double mark() => sw.elapsedMicroseconds / 1000.0;
    ScanResult result;
    try {
      final resident = _byToken[token];
      if (resident == null) {
        result = ScanResult(status: ScanStatus.unknownToken, token: token, message: 'QR token is not registered in Barangay 33-D.');
      } else {
        final prior = await db.latestClaimSince(resident.householdId, _cutoffIso());
        final lookupMs = mark();
        if (prior != null) {
          result = ScanResult(
            status: ScanStatus.alreadyClaimed,
            token: token,
            resident: resident,
            lastClaimAt: DateTime.parse(prior.timestamp).toLocal(),
            message: 'Relief already released within the last ${claimCooldown.inHours} hours.',
          );
        } else {
          final log = DistributionLog(
            transactionId: _uuidV4(),
            householdId: resident.householdId,
            itemsReceived: resident.reliefAllocation,
            timestamp: DateTime.now().toUtc().toIso8601String(),
            workerId: workerId,
            syncedStatus: 0,
          );
          final leaf = MerkleEngine.leafHash(log);
          await db.insertDistributionWithLeaf(log, toHex0x(leaf));
          _pendingLeaves.add(leaf);
          _pendingIds.add(log.transactionId);
          final insertMs = mark();

          final root = MerkleEngine.rootFromLeaves(_pendingLeaves);
          final merkleMs = mark();

          final signature = await _signer!.sign(root);
          checkpoint = OfflineCheckpoint(
            merkleRoot: toHex0x(root),
            signature: toHex0x(signature),
            batchSize: _pendingIds.length,
            createdAt: DateTime.now().toUtc().toIso8601String(),
          );
          await db.saveCheckpoint(checkpoint!);
          final signMs = mark();

          result = ScanResult(
            status: ScanStatus.verified,
            token: token,
            resident: resident,
            transactionId: log.transactionId,
            merkleRoot: checkpoint!.merkleRoot,
            batchSize: _pendingIds.length,
            message: 'Eligible — ${resident.reliefAllocation} relief pack(s) released.',
            timings: ScanTimings(
              lookupMs: lookupMs,
              insertMs: insertMs - lookupMs,
              merkleMs: merkleMs - insertMs,
              signMs: signMs - merkleMs,
              totalMs: signMs,
            ),
          );
          sessionLatencies.add(signMs);
        }
      }
    } catch (e) {
      result = ScanResult(status: ScanStatus.error, token: token, message: 'Verification failed: $e');
    } finally {
      _scanBusy = false;
    }
    lastScan = result;
    await refresh(notify: false);
    notifyListeners();
    return result;
  }

  List<Resident> search(String query, {int limit = 8}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _byId.values
        .where((r) =>
            r.familyHeadName.toLowerCase().contains(q) ||
            r.qrToken.toLowerCase().contains(q) ||
            r.householdId.toLowerCase().contains(q) ||
            'purok ${r.addressPurok}' == q)
        .take(limit)
        .toList(growable: false);
  }

  Resident? randomUnservedResident() {
    final candidates = _byId.values.where((r) => !servedRecently.contains(r.householdId)).toList();
    if (candidates.isEmpty) return null;
    return candidates[Random().nextInt(candidates.length)];
  }

  // ------------------------------------------------------------- dual sync

  Future<void> checkHealth() async {
    final wasOnline = online;
    health = await client.health();
    notifyListeners();
    if (online && !wasOnline && pendingCount > 0) unawaited(syncNow());
  }

  String get _registrationKey => 'registered:$workerId:$publicKeyHex';

  Future<void> _ensureRegistered() async {
    if (_registered) return;
    await client.registerWorker(workerId, publicKeyHex);
    _registered = true;
    await db.setMeta(_registrationKey, 'true');
  }

  /// Uploads the pending batch and R_offline; the daemon recomputes R_cloud and
  /// the LigtasLinkAudit contract anchors or rejects it.
  Future<SyncEvent?> syncNow() async {
    if (syncing || _pendingIds.isEmpty || _signer == null) return null;
    syncing = true;
    notifyListeners();
    final n = _pendingIds.length;
    final ids = List<String>.of(_pendingIds.take(n));
    final root = MerkleEngine.rootFromLeaves(List<Uint8List>.of(_pendingLeaves.take(n)));
    final rootHex = toHex0x(root);
    SyncEvent event;
    try {
      await _ensureRegistered();
      final cp = checkpoint;
      final signatureHex = (cp != null && cp.merkleRoot == rootHex && cp.batchSize == n)
          ? cp.signature
          : toHex0x(await _signer!.sign(root));
      final orphans = await db.orphanPendingLogs();
      final logs = [...await db.logsFor(ids), ...orphans];
      final response = await client.syncBatch(
        rawTransactions: logs.map((l) => l.toSyncJson()).toList(growable: false),
        offlineRoot: rootHex,
        signature: signatureHex,
        workerId: workerId,
      );
      event = await _applySyncResponse(response, ids, rootHex, orphans.map((l) => l.transactionId).toList());
    } catch (e) {
      event = SyncEvent(createdAt: DateTime.now(), kind: SyncEventKind.failed, batchSize: n, merkleRoot: rootHex, message: 'Sync failed: $e');
    }
    await db.addSyncEvent(event);
    syncing = false;
    await refresh(notify: false);
    notifyListeners();
    return event;
  }

  Future<SyncEvent> _applySyncResponse(SyncResponse response, List<String> ids, String rootHex, List<String> orphanIds) async {
    final n = ids.length;
    SyncEvent build(SyncEventKind kind, String message) => SyncEvent(
          createdAt: DateTime.now(),
          kind: kind,
          batchSize: n,
          merkleRoot: rootHex,
          recomputedRoot: response.recomputedRoot,
          chainTxHash: response.chainTxHash,
          message: message,
        );

    switch (response.status) {
      case 'ANCHORED':
      case 'ALREADY_ANCHORED':
        if (!response.synced) {
          return build(SyncEventKind.cloudPending,
              'Root anchored on-chain but Firebase write failed (${response.firebaseReason ?? 'unknown'}). Will retry.');
        }
        await db.markSynced(ids);
        _dropPending(n);
        return build(SyncEventKind.anchored, 'Batch of $n verified: R_cloud == R_offline. Anchored on LigtasLinkAudit.');
      case 'TAMPER_REJECTED':
        await db.quarantine(ids, orphanIds: orphanIds);
        _dropPending(n);
        final injected = orphanIds.isEmpty ? '' : ' ${orphanIds.length} unsigned row(s) were injected outside the app.';
        return build(SyncEventKind.tamperRejected,
            'Tamper detected: R_cloud != R_offline. ${n + orphanIds.length} record(s) quarantined for coordinator review.$injected');
      case 'SIGNATURE_INVALID':
        return build(SyncEventKind.signatureInvalid,
            'Daemon rejected the Ed25519 signature: this device key does not match the key registered for $workerId.');
      case 'UNKNOWN_WORKER':
        _registered = false;
        await db.setMeta(_registrationKey, 'false');
        return build(SyncEventKind.failed, 'Worker $workerId is not registered with the daemon. Will re-register on next sync.');
      default:
        return build(SyncEventKind.failed, response.error ?? 'Sync failed with status ${response.status} (HTTP ${response.httpStatus}).');
    }
  }

  void _dropPending(int n) {
    _pendingIds.removeRange(0, n);
    _pendingLeaves.removeRange(0, n);
    if (checkpoint != null && checkpoint!.batchSize != _pendingIds.length) checkpoint = null;
  }

  // ------------------------------------------------------------- statistics

  List<PurokStats> purokStats() => [
        for (var p = 1; p <= 6; p++)
          () {
            final members = _byId.values.where((r) => r.addressPurok == p);
            return PurokStats(
              purok: p,
              households: members.length,
              served: members.where((r) => servedRecently.contains(r.householdId)).length,
              persons: members.fold(0, (sum, r) => sum + r.householdSize),
              vulnerable: members.where((r) => r.flags.any).length,
            );
          }(),
      ];

  int get totalPersons => _byId.values.fold(0, (sum, r) => sum + r.householdSize);
  int get vulnerableHouseholds => _byId.values.where((r) => r.flags.any).length;

  double? get medianLatencyMs {
    if (sessionLatencies.isEmpty) return null;
    final sorted = List<double>.of(sessionLatencies)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  static String _uuidV4() {
    final rnd = Random.secure();
    final b = List<int>.generate(16, (_) => rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}

/// Exposes the [AppController] to the widget tree and rebuilds dependents on change.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child}) : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
