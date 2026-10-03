import 'package:flutter/material.dart';

import '../models/sync_event.dart';
import '../services/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
      children: [
        const Text('Sync & Tamper Alerts', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const Text('Every dual-sync attempt and its on-chain verdict', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        if (!app.online)
          _Banner(
            icon: Icons.wifi_off,
            color: const Color(0xFFB45309),
            text: 'Offline: ${app.pendingCount} record(s) are signed and queued. They will sync automatically when '
                'the Dual-Sync Daemon and Hardhat node are reachable.',
          ),
        if (app.events.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Column(children: [
              Icon(Icons.notifications_none, size: 48, color: AppColors.textSecondary),
              SizedBox(height: 8),
              Text('No sync activity yet.', style: TextStyle(color: AppColors.textSecondary)),
            ]),
          ),
        for (final e in app.events) _EventCard(event: e),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ]),
      );
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final SyncEvent event;

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon) = switch (event.kind) {
      SyncEventKind.anchored => ('VERIFIED & ANCHORED', BadgeTone.success, Icons.verified),
      SyncEventKind.tamperRejected => ('TAMPER DETECTED', BadgeTone.error, Icons.gpp_bad),
      SyncEventKind.signatureInvalid => ('SIGNATURE INVALID', BadgeTone.error, Icons.key_off),
      SyncEventKind.cloudPending => ('CLOUD WRITE PENDING', BadgeTone.warning, Icons.cloud_sync),
      SyncEventKind.failed => ('SYNC FAILED', BadgeTone.warning, Icons.sync_problem),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(child: StatusBadge(label, tone: tone, icon: icon)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(formatTime(event.createdAt),
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(event.message),
          const SizedBox(height: 8),
          Text('Batch size: ${event.batchSize}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (event.merkleRoot != null) _mono('R_offline', event.merkleRoot!),
          if (event.recomputedRoot != null) _mono('R_cloud', event.recomputedRoot!),
          if (event.chainTxHash != null) _mono('Chain tx', event.chainTxHash!),
        ]),
      ),
    );
  }

  Widget _mono(String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: SelectableText('$k: $v', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary)),
      );
}
