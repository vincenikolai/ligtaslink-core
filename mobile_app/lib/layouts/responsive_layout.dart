import 'package:flutter/material.dart';

import '../models/sync_event.dart';
import '../screens/advice_screen.dart';
import '../screens/alerts_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/home_screen.dart';
import '../screens/prepare_screen.dart';
import '../services/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/header_bar.dart';
import '../widgets/network_indicator.dart';
import '../widgets/scan_actions.dart';
import '../widgets/sidebar.dart';
import 'nav_destinations.dart';

const desktopBreakpoint = 900.0;

/// > 900px: persistent 250px sidebar + top status bar.
/// < 900px: orange AppBar, single column, bottom bar with docked scanner FAB.
class ResponsiveLayout extends StatefulWidget {
  const ResponsiveLayout({super.key});

  @override
  State<ResponsiveLayout> createState() => _ResponsiveLayoutState();
}

class _ResponsiveLayoutState extends State<ResponsiveLayout> {
  int _index = 0;

  Widget _page(bool desktop) => switch (_index) {
        0 => HomeScreen(desktop: desktop),
        1 => const DashboardScreen(),
        2 => const PrepareScreen(),
        3 => const AlertsScreen(),
        _ => const AdviceScreen(),
      };

  int _alertCount(AppController app) =>
      app.events.where((e) => e.kind == SyncEventKind.tamperRejected || e.kind == SyncEventKind.signatureInvalid).length;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final desktop = constraints.maxWidth > desktopBreakpoint;
      return desktop ? _desktop(app) : _mobile(app);
    });
  }

  Widget _desktop(AppController app) => Scaffold(
        body: Column(children: [
          const HeaderBar(),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Sidebar(selected: _index, onSelect: (i) => setState(() => _index = i), alertCount: _alertCount(app)),
              Expanded(child: _page(true)),
            ]),
          ),
        ]),
      );

  // Bottom bar slots: Home, Dashboard, [scanner FAB], Prepare, Alerts. Advice lives in the AppBar.
  static const _mobileSlots = [0, 1, 2, 3];

  Widget _mobile(AppController app) => Scaffold(
        appBar: AppBar(
          titleSpacing: 12,
          title: const Row(children: [
            Icon(Icons.health_and_safety, color: Colors.white),
            SizedBox(width: 8),
            Flexible(child: Text('LigtasLink', overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800))),
          ]),
          actions: [
            const NetworkIndicator(compact: true),
            IconButton(
              tooltip: 'Advice',
              icon: Icon(_index == 4 ? Icons.help : Icons.help_outline),
              onPressed: () => setState(() => _index = 4),
            ),
            IconButton(tooltip: 'Profile', icon: const Icon(Icons.person_pin), onPressed: () => showProfileDialog(context)),
          ],
        ),
        body: _page(false),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Scan household QR',
          shape: const CircleBorder(),
          onPressed: app.ready ? () => startScan(context) : null,
          child: const Icon(Icons.qr_code_scanner, size: 30),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          color: AppColors.surface,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          height: 68,
          padding: EdgeInsets.zero,
          child: Row(children: [
            for (final i in _mobileSlots.take(2)) Expanded(child: _bottomItem(i, app)),
            const SizedBox(width: 72),
            for (final i in _mobileSlots.skip(2)) Expanded(child: _bottomItem(i, app)),
          ]),
        ),
      );

  Widget _bottomItem(int i, AppController app) {
    final d = navDestinations[i];
    final active = _index == i;
    final color = active ? AppColors.brand : AppColors.textSecondary;
    final badge = d.label == 'Alerts' ? _alertCount(app) : 0;
    return InkWell(
      onTap: () => setState(() => _index = i),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Badge(
          isLabelVisible: badge > 0,
          label: Text('$badge'),
          backgroundColor: AppColors.error,
          child: Icon(active ? d.activeIcon : d.icon, color: color),
        ),
        const SizedBox(height: 2),
        Text(d.label, style: TextStyle(fontSize: 11, color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ]),
    );
  }
}
