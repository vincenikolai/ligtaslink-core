import 'package:flutter/material.dart';

import '../models/sync_event.dart';
import '../services/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final stats = app.purokStats();
    final served = app.servedRecently.length;
    final anchoredBatches = app.events.where((e) => e.kind == SyncEventKind.anchored).length;
    final tamperBatches = app.events.where((e) => e.kind == SyncEventKind.tamperRejected).length;
    final median = app.medianLatencyMs;
    final metrics = [
      MetricTile(label: 'Registered households', value: '${app.residents.length}', icon: Icons.groups),
      MetricTile(label: 'Residents covered', value: '${app.totalPersons}', icon: Icons.family_restroom),
      MetricTile(
        label: 'Households served (${AppController.claimCooldown.inHours}h)',
        value: '$served',
        icon: Icons.local_shipping,
        caption: app.residents.isEmpty ? null : '${(served * 100 / app.residents.length).toStringAsFixed(1)}% coverage',
      ),
      MetricTile(label: 'Relief packs released', value: '${app.counts['items'] ?? 0}', icon: Icons.inventory_2),
      MetricTile(label: 'Vulnerable households', value: '${app.vulnerableHouseholds}', icon: Icons.accessible),
      MetricTile(
        label: 'Offline pending',
        value: '${app.pendingCount}',
        icon: app.online ? Icons.wifi : Icons.wifi_off,
        color: app.online ? AppColors.success : const Color(0xFFB45309),
      ),
      MetricTile(label: 'Batches anchored', value: '$anchoredBatches', icon: Icons.verified, color: AppColors.success),
      MetricTile(
        label: 'Tamper rejections',
        value: '$tamperBatches',
        icon: Icons.gpp_bad,
        color: tamperBatches > 0 ? AppColors.error : AppColors.textSecondary,
        caption: '${app.counts['quarantined'] ?? 0} record(s) quarantined',
      ),
      MetricTile(
        label: 'Median scan latency (session)',
        value: median == null ? '—' : '${median.toStringAsFixed(1)} ms',
        icon: Icons.timer,
        color: median == null || median < 100 ? AppColors.success : AppColors.error,
        caption: '${app.sessionLatencies.length} scan(s) • budget 100 ms',
      ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Relief Operations Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const Text('Barangay 33-D, Davao City • live from the offline SQLite ledger',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (context, c) {
              final columns = c.maxWidth > 1000 ? 3 : (c.maxWidth > 560 ? 2 : 1);
              final width = (c.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(spacing: 16, runSpacing: 16, children: [for (final m in metrics) SizedBox(width: width, child: m)]);
            }),
            const SizedBox(height: 24),
            SurfaceCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('Purok Distribution Status'),
                for (final s in stats) _PurokRow(stats: s),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PurokRow extends StatelessWidget {
  const _PurokRow({required this.stats});
  final PurokStats stats;

  @override
  Widget build(BuildContext context) {
    final ratio = stats.households == 0 ? 0.0 : stats.served / stats.households;
    final complete = stats.households > 0 && stats.served == stats.households;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.brandTint,
          child: Text('${stats.purok}', style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Purok ${stats.purok}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${stats.served} / ${stats.households} households',
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                color: complete ? AppColors.success : AppColors.brand,
                backgroundColor: AppColors.brandTint,
              ),
            ),
            const SizedBox(height: 4),
            Text('${stats.persons} residents • ${stats.vulnerable} vulnerable household(s)',
                overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ),
        const SizedBox(width: 12),
        Icon(complete ? Icons.check_circle : Icons.timelapse, color: complete ? AppColors.success : AppColors.textSecondary),
      ]),
    );
  }
}
