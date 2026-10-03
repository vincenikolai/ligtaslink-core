import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/distribution_log.dart';
import '../models/resident.dart';
import '../models/sync_event.dart';
import 'db_factory.dart';

/// A pending Merkle leaf: captured at scan time, independent of the mutable log row.
class PendingLeaf {
  final int seq;
  final String transactionId;
  final String leafHash;
  const PendingLeaf(this.seq, this.transactionId, this.leafHash);
}

class OfflineCheckpoint {
  final String merkleRoot;
  final String signature;
  final int batchSize;
  final String createdAt;
  const OfflineCheckpoint({required this.merkleRoot, required this.signature, required this.batchSize, required this.createdAt});
}

class DbHelper {
  DbHelper._();
  static final DbHelper instance = DbHelper._();

  static const _dbName = 'ligtaslink_local.db';
  static const _dbVersion = 2;
  static const leafPending = 0;
  static const leafSynced = 1;
  static const leafQuarantined = 2;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    configureDatabaseFactory();
    final path = join(await databaseFactory.getDatabasesPath(), _dbName);
    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => _createSchema(db),
        onUpgrade: (db, oldVersion, _) async {
          // Version 1 prototypes used an incompatible schema; rebuild from scratch.
          for (final table in ['merkle_leaves', 'offline_checkpoint', 'sync_events', 'app_meta', 'distribution_logs', 'residents']) {
            await db.execute('DROP TABLE IF EXISTS $table');
          }
          await _createSchema(db);
        },
      ),
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE residents (
        household_id TEXT PRIMARY KEY,
        family_head_name TEXT NOT NULL,
        address_purok INTEGER NOT NULL CHECK (address_purok BETWEEN 1 AND 6),
        dependent_count INTEGER NOT NULL,
        vulnerability_flags TEXT NOT NULL,
        qr_token TEXT NOT NULL UNIQUE
      )''');
    await db.execute('CREATE UNIQUE INDEX idx_residents_qr_token ON residents(qr_token)');
    await db.execute('''
      CREATE TABLE distribution_logs (
        transaction_id TEXT PRIMARY KEY,
        household_id TEXT NOT NULL REFERENCES residents(household_id),
        items_received INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        worker_id TEXT NOT NULL,
        synced_status INTEGER NOT NULL DEFAULT 0 CHECK (synced_status IN (0, 1))
      )''');
    await db.execute('CREATE INDEX idx_logs_household_time ON distribution_logs(household_id, timestamp)');
    await db.execute('CREATE INDEX idx_logs_synced ON distribution_logs(synced_status)');
    // Leaf hashes are frozen at scan time, so editing a log row afterwards
    // produces R_cloud != R_offline when the daemon re-hashes the raw rows.
    await db.execute('''
      CREATE TABLE merkle_leaves (
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id TEXT NOT NULL UNIQUE,
        leaf_hash TEXT NOT NULL,
        state INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('CREATE INDEX idx_leaves_state ON merkle_leaves(state, seq)');
    await db.execute('''
      CREATE TABLE offline_checkpoint (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        merkle_root TEXT NOT NULL,
        signature TEXT NOT NULL,
        batch_size INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE sync_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        kind TEXT NOT NULL,
        merkle_root TEXT,
        recomputed_root TEXT,
        batch_size INTEGER NOT NULL,
        message TEXT NOT NULL,
        chain_tx_hash TEXT
      )''');
    await db.execute('CREATE TABLE app_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
  }

  // ---------------------------------------------------------------- residents

  /// Seeds the 500 Barangay 33-D households from the bundled asset on first launch.
  Future<int> seedResidentsIfEmpty() async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM residents')) ?? 0;
    if (count > 0) return count;
    final raw = await rootBundle.loadString('assets/barangay_33d_households.json');
    final households = (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(Resident.fromJson);
    final batch = db.batch();
    for (final resident in households) {
      batch.insert('residents', resident.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM residents')) ?? 0;
  }

  Future<List<Resident>> allResidents() async {
    final rows = await (await database).query('residents', orderBy: 'household_id');
    return rows.map(Resident.fromRow).toList(growable: false);
  }

  Future<Resident?> findByQrToken(String qrToken) async {
    final rows = await (await database).query('residents', where: 'qr_token = ?', whereArgs: [qrToken], limit: 1);
    return rows.isEmpty ? null : Resident.fromRow(rows.first);
  }

  // ----------------------------------------------------------- distribution

  /// Most recent claim by a household at or after [sinceIsoUtc], if any.
  Future<DistributionLog?> latestClaimSince(String householdId, String sinceIsoUtc) async {
    final rows = await (await database).query(
      'distribution_logs',
      where: 'household_id = ? AND timestamp >= ?',
      whereArgs: [householdId, sinceIsoUtc],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : DistributionLog.fromRow(rows.first);
  }

  /// Inserts the log row and its frozen Merkle leaf atomically.
  Future<void> insertDistributionWithLeaf(DistributionLog log, String leafHash) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('distribution_logs', log.toRow(), conflictAlgorithm: ConflictAlgorithm.abort);
      await txn.insert('merkle_leaves', {'transaction_id': log.transactionId, 'leaf_hash': leafHash, 'state': leafPending});
    });
  }

  Future<List<PendingLeaf>> pendingLeaves() async {
    final rows = await (await database).query('merkle_leaves', where: 'state = ?', whereArgs: [leafPending], orderBy: 'seq ASC');
    return rows
        .map((r) => PendingLeaf(r['seq'] as int, r['transaction_id'] as String, r['leaf_hash'] as String))
        .toList(growable: false);
  }

  /// Raw log rows for the given transaction IDs, returned in the given order.
  /// Rows deleted from the database are simply absent, which the daemon detects.
  Future<List<DistributionLog>> logsFor(List<String> transactionIds) async {
    if (transactionIds.isEmpty) return const [];
    final db = await database;
    final byId = <String, DistributionLog>{};
    for (var i = 0; i < transactionIds.length; i += 500) {
      final chunk = transactionIds.sublist(i, i + 500 > transactionIds.length ? transactionIds.length : i + 500);
      final rows = await db.query(
        'distribution_logs',
        where: 'transaction_id IN (${List.filled(chunk.length, '?').join(',')})',
        whereArgs: chunk,
      );
      for (final row in rows) {
        final log = DistributionLog.fromRow(row);
        byId[log.transactionId] = log;
      }
    }
    return [for (final id in transactionIds) if (byId[id] != null) byId[id]!];
  }

  /// Unsynced rows with no Merkle leaf can only come from writes that bypassed
  /// the app. They are appended to the upload so the daemon's root cannot match.
  Future<List<DistributionLog>> orphanPendingLogs() async {
    final rows = await (await database).rawQuery('''
      SELECT * FROM distribution_logs
      WHERE synced_status = 0
        AND transaction_id NOT IN (SELECT transaction_id FROM merkle_leaves)
      ORDER BY rowid''');
    return rows.map(DistributionLog.fromRow).toList(growable: false);
  }

  Future<void> markSynced(List<String> transactionIds) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final id in transactionIds) {
        batch.update('distribution_logs', {'synced_status': 1}, where: 'transaction_id = ?', whereArgs: [id]);
        batch.update('merkle_leaves', {'state': leafSynced}, where: 'transaction_id = ?', whereArgs: [id]);
      }
      batch.delete('offline_checkpoint');
      await batch.commit(noResult: true);
    });
  }

  /// Removes a rejected batch from the pending set so new scans form a fresh batch.
  /// Rows stay in distribution_logs (synced_status = 0) as evidence for the coordinator.
  Future<void> quarantine(List<String> transactionIds, {List<String> orphanIds = const []}) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final id in transactionIds) {
        batch.update('merkle_leaves', {'state': leafQuarantined}, where: 'transaction_id = ?', whereArgs: [id]);
      }
      for (final id in orphanIds) {
        batch.insert('merkle_leaves', {'transaction_id': id, 'leaf_hash': '', 'state': leafQuarantined},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      batch.delete('offline_checkpoint');
      await batch.commit(noResult: true);
    });
  }

  Future<List<LogView>> recentLogs({int limit = 50}) async {
    final rows = await (await database).rawQuery('''
      SELECT l.*, r.family_head_name, r.address_purok, m.state AS leaf_state
      FROM distribution_logs l
      JOIN residents r ON r.household_id = l.household_id
      LEFT JOIN merkle_leaves m ON m.transaction_id = l.transaction_id
      ORDER BY l.timestamp DESC
      LIMIT ?''', [limit]);
    return rows.map((row) {
      final leafState = row['leaf_state'] as int?;
      final state = leafState == leafQuarantined
          ? LogState.quarantined
          : (row['synced_status'] as int) == 1
              ? LogState.synced
              : LogState.pending;
      return LogView(
        log: DistributionLog.fromRow(row),
        familyHeadName: row['family_head_name'] as String,
        addressPurok: row['address_purok'] as int,
        state: state,
      );
    }).toList(growable: false);
  }

  // ------------------------------------------------------------- checkpoint

  Future<void> saveCheckpoint(OfflineCheckpoint checkpoint) async {
    await (await database).insert(
      'offline_checkpoint',
      {
        'id': 1,
        'merkle_root': checkpoint.merkleRoot,
        'signature': checkpoint.signature,
        'batch_size': checkpoint.batchSize,
        'created_at': checkpoint.createdAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<OfflineCheckpoint?> loadCheckpoint() async {
    final rows = await (await database).query('offline_checkpoint', where: 'id = 1');
    if (rows.isEmpty) return null;
    final r = rows.first;
    return OfflineCheckpoint(
      merkleRoot: r['merkle_root'] as String,
      signature: r['signature'] as String,
      batchSize: r['batch_size'] as int,
      createdAt: r['created_at'] as String,
    );
  }

  // ------------------------------------------------------------ sync events

  Future<void> addSyncEvent(SyncEvent event) async => (await database).insert('sync_events', event.toRow());

  Future<List<SyncEvent>> syncEvents({int limit = 100}) async {
    final rows = await (await database).query('sync_events', orderBy: 'id DESC', limit: limit);
    return rows.map(SyncEvent.fromRow).toList(growable: false);
  }

  // ------------------------------------------------------------- statistics

  Future<Map<String, int>> counts() async {
    final db = await database;
    Future<int> one(String sql, [List<Object?> args = const []]) async =>
        Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
    return {
      'logs': await one('SELECT COUNT(*) FROM distribution_logs'),
      'items': await one('SELECT COALESCE(SUM(items_received), 0) FROM distribution_logs'),
      'synced': await one('SELECT COUNT(*) FROM distribution_logs WHERE synced_status = 1'),
      'pending': await one('SELECT COUNT(*) FROM merkle_leaves WHERE state = ?', [leafPending]),
      'quarantined': await one('SELECT COUNT(*) FROM merkle_leaves WHERE state = ?', [leafQuarantined]),
    };
  }

  /// Households served at least once since [sinceIsoUtc], keyed by household_id.
  Future<Set<String>> householdsServedSince(String sinceIsoUtc) async {
    final rows = await (await database).rawQuery(
      'SELECT DISTINCT household_id FROM distribution_logs WHERE timestamp >= ?',
      [sinceIsoUtc],
    );
    return rows.map((r) => r['household_id'] as String).toSet();
  }

  // ----------------------------------------------------------------- meta

  Future<String?> getMeta(String key) async {
    final rows = await (await database).query('app_meta', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setMeta(String key, String value) async =>
      (await database).insert('app_meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
}
