enum LogState { pending, synced, quarantined }

class DistributionLog {
  final String transactionId;
  final String householdId;
  final int itemsReceived;
  final String timestamp;
  final String workerId;
  final int syncedStatus;

  const DistributionLog({
    required this.transactionId,
    required this.householdId,
    required this.itemsReceived,
    required this.timestamp,
    required this.workerId,
    required this.syncedStatus,
  });

  factory DistributionLog.fromRow(Map<String, Object?> row) => DistributionLog(
        transactionId: row['transaction_id'] as String,
        householdId: row['household_id'] as String,
        itemsReceived: row['items_received'] as int,
        timestamp: row['timestamp'] as String,
        workerId: row['worker_id'] as String,
        syncedStatus: row['synced_status'] as int,
      );

  Map<String, Object?> toRow() => {
        'transaction_id': transactionId,
        'household_id': householdId,
        'items_received': itemsReceived,
        'timestamp': timestamp,
        'worker_id': workerId,
        'synced_status': syncedStatus,
      };

  /// The five fields that make up the Merkle leaf; sent to the Dual-Sync Daemon.
  Map<String, Object> toSyncJson() => {
        'transaction_id': transactionId,
        'household_id': householdId,
        'items_received': itemsReceived,
        'timestamp': timestamp,
        'worker_id': workerId,
      };
}

/// A log row joined with resident details for display in the live log table.
class LogView {
  final DistributionLog log;
  final String familyHeadName;
  final int addressPurok;
  final LogState state;

  const LogView({required this.log, required this.familyHeadName, required this.addressPurok, required this.state});
}
