import 'package:flutter/material.dart';

import '../models/distribution_log.dart';
import '../services/app_controller.dart';
import '../theme/app_theme.dart';
import 'common.dart';

StatusBadge stateBadge(LogState state) => switch (state) {
      LogState.synced => const StatusBadge('Anchored', tone: BadgeTone.success, icon: Icons.verified),
      LogState.pending => const StatusBadge('Offline Pending', tone: BadgeTone.warning, icon: Icons.schedule),
      LogState.quarantined => const StatusBadge('Tamper Quarantine', tone: BadgeTone.error, icon: Icons.gpp_bad),
    };

/// Desktop: full data table. Mobile: compact list.
class LiveLogTable extends StatelessWidget {
  const LiveLogTable({super.key, this.compact = false, this.limit = 50});
  final bool compact;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final logs = app.recentLogs.take(limit).toList();
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle('Live Distribution Log',
            trailing: Text('${app.counts['logs'] ?? 0} total', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
        if (logs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Column(children: [
              Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textSecondary),
              SizedBox(height: 8),
              Text('No relief released yet. Scan a household QR card to begin.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            ]),
          )
        else if (compact)
          ...logs.map((v) => _LogTile(view: v))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary, fontSize: 12),
              dataTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              columnSpacing: 22,
              headingRowHeight: 40,
              columns: const [
                DataColumn(label: Text('TIME')),
                DataColumn(label: Text('HOUSEHOLD')),
                DataColumn(label: Text('FAMILY HEAD')),
                DataColumn(label: Text('PUROK'), numeric: true),
                DataColumn(label: Text('ITEMS'), numeric: true),
                DataColumn(label: Text('TRANSACTION')),
                DataColumn(label: Text('STATUS')),
              ],
              rows: [
                for (final v in logs)
                  DataRow(cells: [
                    DataCell(Text(formatClock(DateTime.parse(v.log.timestamp)))),
                    DataCell(Text(v.log.householdId)),
                    DataCell(Text(v.familyHeadName)),
                    DataCell(Text('${v.addressPurok}')),
                    DataCell(Text('${v.log.itemsReceived}')),
                    DataCell(Text(shortHash(v.log.transactionId, head: 8, tail: 4),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                    DataCell(stateBadge(v.state)),
                  ]),
              ],
            ),
          ),
      ]),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.view});
  final LogView view;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.brandTint,
            child: Text('P${view.addressPurok}', style: const TextStyle(color: AppColors.brand, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(view.familyHeadName, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${formatClock(DateTime.parse(view.log.timestamp))} • ${view.log.itemsReceived} pack(s)',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
          stateBadge(view.state),
        ]),
      );
}
