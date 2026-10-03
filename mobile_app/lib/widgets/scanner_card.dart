import 'package:flutter/material.dart';

import '../models/scan_result.dart';
import '../services/app_controller.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'scan_actions.dart';

/// "Household Verification" card: QR viewport, last result and latency budget.
class ScannerCard extends StatelessWidget {
  const ScannerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final scan = app.lastScan;
    return SurfaceCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Household Verification'),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.brandTint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.brand, width: 2),
          ),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.qr_code_scanner, size: 80, color: AppColors.brand),
            SizedBox(height: 8),
            Text('Scan the household relief QR card', style: TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
        const SizedBox(height: 16),
        if (scan != null) _ScanOutcome(scan: scan),
        if (scan != null) const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: app.ready ? () => startScan(context) : null,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Scan QR Code'),
        ),
      ]),
    );
  }
}

class _ScanOutcome extends StatelessWidget {
  const _ScanOutcome({required this.scan});
  final ScanResult scan;

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon) = switch (scan.status) {
      ScanStatus.verified => ('VERIFIED', BadgeTone.success, Icons.verified_user),
      ScanStatus.alreadyClaimed => ('ALREADY CLAIMED', BadgeTone.error, Icons.block),
      ScanStatus.unknownToken => ('NOT REGISTERED', BadgeTone.error, Icons.gpp_bad),
      ScanStatus.error => ('ERROR', BadgeTone.error, Icons.error_outline),
    };
    final r = scan.resident;
    final t = scan.timings;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.page, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: StatusBadge(label, tone: tone, icon: icon)),
          const SizedBox(width: 8),
          Text(formatClock(scan.at), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 10),
        Text(r?.familyHeadName ?? scan.token, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (r != null)
          Text('${r.householdId} • Purok ${r.addressPurok} • ${r.householdSize} member(s)',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        if (r != null && r.flags.any)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 6, children: [for (final f in r.flags.labels) StatusBadge(f, tone: BadgeTone.brand)]),
          ),
        const SizedBox(height: 6),
        Text(scan.message),
        if (scan.lastClaimAt != null)
          Text('Last claim: ${formatTime(scan.lastClaimAt!)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        if (t != null) ...[
          const Divider(height: 20),
          Row(children: [
            Icon(Icons.timer_outlined, size: 16, color: t.underThreshold ? AppColors.success : AppColors.error),
            const SizedBox(width: 6),
            Text('${t.totalMs.toStringAsFixed(1)} ms',
                style: TextStyle(fontWeight: FontWeight.w800, color: t.underThreshold ? AppColors.success : AppColors.error)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(t.underThreshold ? 'under 100 ms budget' : 'over 100 ms budget',
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            'lookup ${t.lookupMs.toStringAsFixed(1)} • insert ${t.insertMs.toStringAsFixed(1)} • '
            'merkle ${t.merkleMs.toStringAsFixed(1)} • sign ${t.signMs.toStringAsFixed(1)} ms',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text('R_offline ${shortHash(scan.merkleRoot)} • batch ${scan.batchSize}',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary)),
        ],
      ]),
    );
  }
}
