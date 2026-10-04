import 'package:flutter/material.dart';

import '../models/scan_result.dart';
import '../screens/qr_scan_screen.dart';
import '../services/app_controller.dart';
import '../theme/app_theme.dart';
import 'dialogs.dart';

/// Opens the camera (or manual token entry where no camera plugin exists) and
/// runs the offline verification pipeline on the result.
Future<void> startScan(BuildContext context) async {
  final app = AppScope.of(context);
  final String? token;
  if (cameraScanSupported) {
    token = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
  } else {
    token = await showManualTokenDialog(context, app);
  }
  if (token == null || token.isEmpty || !context.mounted) return;
  await verifyAndNotify(context, token);
}

Future<void> verifyAndNotify(BuildContext context, String token) async {
  final app = AppScope.of(context);
  final result = await app.verifyToken(token);
  if (!context.mounted) return;
  final latency = result.timings == null ? '' : ' (${result.timings!.totalMs.toStringAsFixed(1)} ms)';
  final who = result.resident == null ? result.token : result.resident!.familyHeadName;
  showScanSnack(context, '$who: ${result.message}$latency', ok: result.status == ScanStatus.verified);
}

Future<String?> showManualTokenDialog(BuildContext context, AppController app) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.qr_code_scanner, color: AppColors.brand, size: 40),
      title: const Text('Enter QR token'),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'No camera scanner on this platform. Type the token printed under the household QR code, '
            'or use a handheld USB scanner (it types into this field).',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.qr_code), hintText: 'TOKEN-B33D-P1-001'),
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.casino_outlined),
              label: const Text('Fill a random unserved household (drill mode)'),
              onPressed: () {
                final r = app.randomUnservedResident();
                if (r != null) controller.text = r.qrToken;
              },
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(minimumSize: const Size(140, 44)),
          icon: const Icon(Icons.verified_user),
          label: const Text('Verify'),
          onPressed: () => Navigator.pop(context, controller.text.trim()),
        ),
      ],
    ),
  );
}
