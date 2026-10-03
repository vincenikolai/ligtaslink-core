import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import '../theme/app_theme.dart';
import 'dialogs.dart';
import 'network_indicator.dart';

/// Desktop top status bar: brand, network/dual-sync state, worker profile.
class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(color: AppColors.brand, boxShadow: AppTheme.cardShadow),
      child: Row(children: [
        const Icon(Icons.health_and_safety, color: Colors.white, size: 30),
        const SizedBox(width: 10),
        const Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('LigtasLink', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          Text('Barangay 33-D, Davao City • Relief Verification', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
        const Spacer(),
        const NetworkIndicator(),
        const SizedBox(width: 12),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          onPressed: app.online && app.pendingCount > 0 && !app.syncing ? app.syncNow : null,
          icon: const Icon(Icons.sync),
          label: const Text('Sync'),
        ),
        const SizedBox(width: 8),
        InkWell(
          customBorder: const CircleBorder(),
          onTap: () => showProfileDialog(context),
          child: Row(children: [
            const CircleAvatar(radius: 18, backgroundColor: Colors.white, child: Icon(Icons.person_pin, color: AppColors.brand)),
            const SizedBox(width: 8),
            Text(app.workerId, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}
