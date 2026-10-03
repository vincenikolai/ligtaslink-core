import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import '../theme/app_theme.dart';

/// Icons.wifi_off (amber) while offline; Icons.wifi (green) when dual-sync is active.
class NetworkIndicator extends StatelessWidget {
  const NetworkIndicator({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final online = app.online;
    final color = online ? AppColors.success : AppColors.offline;
    final label = app.syncing
        ? 'Syncing…'
        : online
            ? 'Dual-Sync Active'
            : app.health.reachable
                ? 'Chain offline'
                : 'Offline';
    final tooltip = online
        ? 'Daemon ${app.client.baseUrl} • Hardhat chainId 31337 • ${app.pendingCount} pending'
        : 'Working offline • ${app.pendingCount} record(s) queued\n${app.health.error ?? ''}'.trim();
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (app.syncing)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand))
          else
            Icon(online ? Icons.wifi : Icons.wifi_off, size: 18, color: color),
          if (!compact) ...[
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
          if (app.pendingCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(10)),
              child: Text('${app.pendingCount}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
    );
  }
}
