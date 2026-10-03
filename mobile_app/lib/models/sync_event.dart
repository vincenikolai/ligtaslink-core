enum SyncEventKind { anchored, tamperRejected, signatureInvalid, cloudPending, failed }

class SyncEvent {
  final int? id;
  final DateTime createdAt;
  final SyncEventKind kind;
  final String? merkleRoot;
  final String? recomputedRoot;
  final int batchSize;
  final String message;
  final String? chainTxHash;

  const SyncEvent({
    this.id,
    required this.createdAt,
    required this.kind,
    required this.batchSize,
    required this.message,
    this.merkleRoot,
    this.recomputedRoot,
    this.chainTxHash,
  });

  factory SyncEvent.fromRow(Map<String, Object?> row) => SyncEvent(
        id: row['id'] as int?,
        createdAt: DateTime.parse(row['created_at'] as String),
        kind: SyncEventKind.values.byName(row['kind'] as String),
        merkleRoot: row['merkle_root'] as String?,
        recomputedRoot: row['recomputed_root'] as String?,
        batchSize: row['batch_size'] as int,
        message: row['message'] as String,
        chainTxHash: row['chain_tx_hash'] as String?,
      );

  Map<String, Object?> toRow() => {
        'created_at': createdAt.toUtc().toIso8601String(),
        'kind': kind.name,
        'merkle_root': merkleRoot,
        'recomputed_root': recomputedRoot,
        'batch_size': batchSize,
        'message': message,
        'chain_tx_hash': chainTxHash,
      };
}
