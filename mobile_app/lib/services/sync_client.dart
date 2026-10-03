import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DaemonHealth {
  final bool reachable;
  final bool chainConnected;
  final bool firebaseEnabled;
  final String? contractAddress;
  final String? error;

  const DaemonHealth({
    required this.reachable,
    required this.chainConnected,
    required this.firebaseEnabled,
    this.contractAddress,
    this.error,
  });

  const DaemonHealth.unreachable(String this.error)
      : reachable = false,
        chainConnected = false,
        firebaseEnabled = false,
        contractAddress = null;

  /// Dual-sync is only "active" when both the daemon and the Hardhat node respond.
  bool get dualSyncActive => reachable && chainConnected;
}

class SyncResponse {
  final int httpStatus;
  final Map<String, dynamic> body;
  const SyncResponse(this.httpStatus, this.body);

  String get status => body['status'] as String? ?? 'UNKNOWN';
  bool get verified => body['verified'] == true;
  bool get synced => body['synced'] == true;
  String? get recomputedRoot => body['recomputedRoot'] as String?;
  String? get error => body['error'] as String?;
  String? get chainTxHash => (body['chain'] as Map?)?['txHash'] as String?;
  String? get firebaseReason => (body['firebase'] as Map?)?['reason'] as String?;
}

class SyncException implements Exception {
  final String message;
  const SyncException(this.message);
  @override
  String toString() => message;
}

/// HTTP client for the Node.js Dual-Sync Daemon (backend_daemon/server.js).
class SyncClient {
  SyncClient({String? baseUrl, http.Client? httpClient})
      : baseUrl = baseUrl ?? defaultBaseUrl(),
        _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  static const _healthTimeout = Duration(seconds: 4);
  static const _syncTimeout = Duration(seconds: 30);

  /// Override with `--dart-define=DAEMON_URL=http://<host>:8080`.
  static String defaultBaseUrl() {
    const fromEnv = String.fromEnvironment('DAEMON_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8080';
    return 'http://127.0.0.1:8080';
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<DaemonHealth> health() async {
    try {
      final res = await _http.get(_uri('/health')).timeout(_healthTimeout);
      if (res.statusCode != 200) return DaemonHealth.unreachable('Daemon returned HTTP ${res.statusCode}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final chain = body['chain'] as Map<String, dynamic>? ?? const {};
      final firebase = body['firebase'] as Map<String, dynamic>? ?? const {};
      return DaemonHealth(
        reachable: true,
        chainConnected: chain['connected'] == true,
        firebaseEnabled: firebase['enabled'] == true,
        contractAddress: chain['contract'] as String?,
        error: chain['connected'] == true ? null : chain['error'] as String?,
      );
    } catch (e) {
      return DaemonHealth.unreachable('$e');
    }
  }

  Future<void> registerWorker(String workerId, String publicKeyHex) async {
    final res = await _http
        .post(_uri('/api/workers/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'workerId': workerId, 'publicKey': publicKeyHex}))
        .timeout(_syncTimeout);
    if (res.statusCode == 200 || res.statusCode == 201) return;
    throw SyncException(_errorOf(res) ?? 'Worker registration failed (HTTP ${res.statusCode})');
  }

  Future<SyncResponse> syncBatch({
    required List<Map<String, Object>> rawTransactions,
    required String offlineRoot,
    required String signature,
    required String workerId,
  }) async {
    final res = await _http
        .post(_uri('/api/sync-batch'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'rawTransactions': rawTransactions,
              'offlineRoot': offlineRoot,
              'signature': signature,
              'workerId': workerId,
            }))
        .timeout(_syncTimeout);
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } on FormatException {
      throw SyncException('Daemon returned a non-JSON response (HTTP ${res.statusCode})');
    }
    if (res.statusCode == 400) throw SyncException(body['error'] as String? ?? 'Batch rejected as malformed');
    return SyncResponse(res.statusCode, body);
  }

  String? _errorOf(http.Response res) {
    try {
      return (jsonDecode(res.body) as Map<String, dynamic>)['error'] as String?;
    } catch (_) {
      return null;
    }
  }
}
