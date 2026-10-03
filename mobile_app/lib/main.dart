import 'package:flutter/material.dart';

import 'layouts/responsive_layout.dart';
import 'services/app_controller.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  runApp(LigtasLinkApp(controller: controller));
  controller.init();
}

class LigtasLinkApp extends StatelessWidget {
  const LigtasLinkApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => AppScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'LigtasLink',
          theme: AppTheme.light(),
          home: const _Bootstrap(),
        ),
      );
}

class _Bootstrap extends StatelessWidget {
  const _Bootstrap();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (app.ready) return const ResponsiveLayout();
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.health_and_safety, size: 72, color: AppColors.brand),
            const SizedBox(height: 16),
            const Text('LigtasLink', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            if (app.initError == null) ...[
              const CircularProgressIndicator(color: AppColors.brand),
              const SizedBox(height: 12),
              const Text('Preparing offline ledger…', style: TextStyle(color: AppColors.textSecondary)),
            ] else ...[
              const Icon(Icons.error_outline, color: AppColors.error, size: 32),
              const SizedBox(height: 8),
              Text('Could not open the local database:\n${app.initError}',
                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
            ],
          ]),
        ),
      ),
    );
  }
}
