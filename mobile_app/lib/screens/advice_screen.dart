import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';

const _topics = <(IconData, String, String)>[
  (
    Icons.qr_code_scanner,
    'How household verification works',
    'Scan the household QR card. LigtasLink looks up the token in the offline roster using an in-memory hash map, '
        'which takes constant time, and checks that the household has not claimed relief in the last 72 hours. It then '
        'records the release in the local SQLite ledger. No internet connection is needed.'
  ),
  (
    Icons.account_tree,
    'What the Merkle root and signature mean',
    'Each release is hashed (SHA-256) into a leaf of a Merkle tree. All pending leaves are combined pair by pair '
        'into a single root, R_offline, which this device signs with its Ed25519 worker key. Changing any record '
        'afterwards changes the root.'
  ),
  (
    Icons.cloud_sync,
    'What happens when connectivity returns',
    'The Dual-Sync Daemon receives the raw records together with R_offline and its signature. It recomputes '
        'R_cloud from the raw records and submits both roots to the LigtasLinkAudit smart contract. If they match, '
        'the batch is anchored on-chain and written to Firebase.'
  ),
  (
    Icons.gpp_bad,
    'If you see a TAMPER DETECTED alert',
    'The records on this device were changed after they were signed. The affected records are quarantined and '
        'kept as evidence. Do not delete the app or its data. Report to the Barangay 33-D relief coordinator '
        'immediately. New scans continue in a fresh batch.'
  ),
  (
    Icons.wifi_off,
    'Working without signal',
    'Keep scanning. Every record is stored and signed locally. The amber Wi-Fi icon shows how many records are '
        'queued. Sync starts automatically when the icon turns green.'
  ),
  (
    Icons.flood,
    'Flood and typhoon safety reminders',
    'Move to higher ground early when PAGASA raises rainfall or wind warnings. Never walk or drive through '
        'floodwater. Switch off the main power before evacuating. Bring the household QR card so your family can '
        'receive relief at the evacuation center.'
  ),
  (
    Icons.crisis_alert,
    'Earthquake reminders',
    'Drop, cover and hold on until the shaking stops. Evacuate using stairs, not elevators. Stay away from damaged '
        'buildings and slopes, and expect aftershocks.'
  ),
];

class AdviceScreen extends StatelessWidget {
  const AdviceScreen({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: [
          const Text('Advice & Help', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const Text('Guidance for frontline workers and residents', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          for (final t in _topics)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SurfaceCard(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: CircleAvatar(backgroundColor: AppColors.brandTint, child: Icon(t.$1, color: AppColors.brand)),
                    title: Text(t.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    children: [Text(t.$3, style: const TextStyle(height: 1.5))],
                  ),
                ),
              ),
            ),
        ],
      );
}
