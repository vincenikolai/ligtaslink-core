import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Offline Merkle batch state (R_offline, signature) with manual dual-sync trigger.
class BatchCard extends StatelessWidget {
  const BatchCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final cp = app.checkpoint;
    final last = app.events.isEmpty ? null : app.events.first;
    return SurfaceCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle('Offline Merkle Batch',
            trailing: app.online
                ? const StatusBadge('Online', tone: BadgeTone.success, icon: Icons.wifi)
                : const StatusBadge('Offline', tone: BadgeTone.warning, icon: Icons.wifi_off)),
        Row(children: [
          Expanded(child: _Stat(label: 'Pending logs', value: '${app.pendingCount}')),
          Expanded(child: _Stat(label: 'Tree height', value: '${app.treeHeight}')),
          Expanded(child: _Stat(label: 'Anchored', value: '${app.counts['synced'] ?? 0}')),
        ]),
        const SizedBox(height: 12),
        _HashLine(label: 'R_offline', value: cp?.merkleRoot),
        _HashLine(label: 'Ed25519 sig', value: cp?.signature),
        if (last != null) ...[
          const SizedBox(height: 8),
          Text('Last sync: ${formatTime(last.createdAt)} — ${last.message}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 14),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.brand,
            side: const BorderSide(color: AppColors.brand),
            minimumSize: const Size(0, 46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
          ),
          onPressed: app.pendingCount == 0 || app.syncing || !app.online ? null : app.syncNow,
          icon: app.syncing
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.cloud_upload_outlined),
          label: Text(app.online
              ? (app.pendingCount == 0 ? 'Nothing to sync' : 'Sync ${app.pendingCount} record(s) now')
              : 'Waiting for connectivity'),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ]);
}

class _HashLine extends StatelessWidget {
  const _HashLine({required this.label, required this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          SizedBox(width: 92, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          Expanded(
            child: Tooltip(
              message: value ?? 'No pending batch',
              child: Text(shortHash(value, head: 14, tail: 8),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textPrimary)),
            ),
          ),
        ]),
      );
}
