import 'resident.dart';

enum ScanStatus { verified, alreadyClaimed, unknownToken, error }

class ScanTimings {
  final double lookupMs;
  final double insertMs;
  final double merkleMs;
  final double signMs;
  final double totalMs;

  const ScanTimings({
    required this.lookupMs,
    required this.insertMs,
    required this.merkleMs,
    required this.signMs,
    required this.totalMs,
  });

  bool get underThreshold => totalMs < 100;
}

class ScanResult {
  final ScanStatus status;
  final String token;
  final Resident? resident;
  final String message;
  final String? transactionId;
  final String? merkleRoot;
  final int? batchSize;
  final DateTime? lastClaimAt;
  final ScanTimings? timings;
  final DateTime at;

  ScanResult({
    required this.status,
    required this.token,
    required this.message,
    this.resident,
    this.transactionId,
    this.merkleRoot,
    this.batchSize,
    this.lastClaimAt,
    this.timings,
  }) : at = DateTime.now();

  bool get isVerified => status == ScanStatus.verified;
}
