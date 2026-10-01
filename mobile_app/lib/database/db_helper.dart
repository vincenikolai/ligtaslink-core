import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DbHelper {
  DbHelper._();
  static final instance = DbHelper._();
  Database? _db;
  Future<Database> get database async => _db ??= await openDatabase(
    join(await getDatabasesPath(), 'ligtaslink_local.db'),
    version: 1,
    onCreate: (db, _) async {
      await db.execute('CREATE TABLE residents (household_id TEXT PRIMARY KEY, family_head_name TEXT NOT NULL, address_purok INTEGER NOT NULL, dependent_count INTEGER NOT NULL, vulnerability_flags TEXT NOT NULL, qr_token TEXT NOT NULL UNIQUE)');
      await db.execute('CREATE TABLE distribution_logs (transaction_id TEXT PRIMARY KEY, household_id TEXT NOT NULL, items_received INTEGER NOT NULL, timestamp TEXT NOT NULL, worker_id TEXT NOT NULL, synced_status INTEGER NOT NULL DEFAULT 0)');
      await db.execute('CREATE INDEX idx_residents_qr_token ON residents(qr_token)');
      await db.execute('CREATE INDEX idx_distribution_household_time ON distribution_logs(household_id, timestamp)');
    },
  );

  Future<Map<String, Object?>?> findEligibleByQr(String qrToken, {DateTime? now}) async {
    final db = await database;
    final residents = await db.query('residents', where: 'qr_token = ?', whereArgs: [qrToken], limit: 1);
    if (residents.isEmpty) return null;
    final cutoff = (now ?? DateTime.now().toUtc()).subtract(const Duration(days: 3)).toIso8601String();
    final recent = await db.query('distribution_logs', columns: ['transaction_id'], where: 'household_id = ? AND timestamp >= ?', whereArgs: [residents.first['household_id'], cutoff], limit: 1);
    return recent.isEmpty ? residents.first : null;
  }

  Future<void> insertResident(Map<String, Object?> resident) async => (await database).insert('residents', resident, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> insertDistribution(Map<String, Object?> log) async => (await database).insert('distribution_logs', log, conflictAlgorithm: ConflictAlgorithm.abort);
  Future<List<Map<String, Object?>>> pendingBatch({int limit = 100}) async => (await database).query('distribution_logs', where: 'synced_status = 0', orderBy: 'timestamp ASC', limit: limit);
  Future<void> markSynced(Iterable<String> ids) async { final db = await database; final batch = db.batch(); for (final id in ids) { batch.update('distribution_logs', {'synced_status': 1}, where: 'transaction_id = ?', whereArgs: [id]); } await batch.commit(noResult: true); }
  Map<String, Object?> encodeFlags(Map<String, bool> flags) => {'vulnerability_flags': jsonEncode(flags)};
}
