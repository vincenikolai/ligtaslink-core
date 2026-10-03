import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_controller.dart';
import '../theme/app_theme.dart';
import 'common.dart';

Future<void> showSosDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
          child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
        ),
        title: const Text('Emergency Support'),
        content: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('For life-threatening emergencies in Davao City, call Central 911 immediately.'),
          SizedBox(height: 16),
          _Hotline(icon: Icons.emergency, label: 'Davao City Central 911', number: '911'),
          _Hotline(icon: Icons.medical_services, label: 'Philippine Red Cross', number: '143'),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );

class _Hotline extends StatelessWidget {
  const _Hotline({required this.icon, required this.label, required this.number});
  final IconData icon;
  final String label;
  final String number;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(backgroundColor: AppColors.brandTint, child: Icon(icon, color: AppColors.brand)),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(number),
        trailing: IconButton(
          tooltip: 'Call $number',
          icon: const Icon(Icons.call, color: AppColors.success),
          onPressed: () async {
            final launched = await launchUrl(Uri(scheme: 'tel', path: number));
            if (!launched && context.mounted) {
              await Clipboard.setData(ClipboardData(text: number));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calling not supported here — $number copied.')));
              }
            }
          },
        ),
      );
}

Future<void> showProfileDialog(BuildContext context) {
  final app = AppScope.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.person_pin, size: 48, color: AppColors.brand),
      title: Text('Frontline Worker ${app.workerId}'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _kv('Assignment', 'Barangay 33-D, Davao City'),
          _kv('Ed25519 public key', app.publicKeyHex, copy: true, context: context),
          _kv('Dual-Sync Daemon', app.client.baseUrl),
          _kv('Hardhat contract', app.health.contractAddress ?? 'Not connected'),
          _kv('Firebase', app.health.reachable ? (app.health.firebaseEnabled ? 'Enabled' : 'Disabled on daemon') : 'Unknown (offline)'),
          _kv('Registered households', '${app.residents.length}'),
          _kv('Pending batch', '${app.pendingCount} record(s), tree height ${app.treeHeight}'),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ),
  );
}

Widget _kv(String k, String v, {bool copy = false, BuildContext? context}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Row(children: [
          Expanded(child: SelectableText(v, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (copy && context != null)
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => Clipboard.setData(ClipboardData(text: v)),
            ),
        ]),
      ]),
    );

/// Shown after every scan with the verification outcome and latency breakdown.
void showScanSnack(BuildContext context, String message, {required bool ok}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: ok ? AppColors.success : AppColors.error,
      content: Row(children: [
        Icon(ok ? Icons.verified_user : Icons.gpp_bad, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
    ));
}

Future<void> showInfoSheet(BuildContext context, {required IconData icon, required String title, required Widget body}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.page,
      constraints: const BoxConstraints(maxWidth: 720),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Row(children: [
              CircleAvatar(backgroundColor: AppColors.brand, child: Icon(icon, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 16),
            body,
          ],
        ),
      ),
    );

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.title, required this.value, this.subtitle});
  final String title;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.brand)),
          ]),
        ),
      );
}
