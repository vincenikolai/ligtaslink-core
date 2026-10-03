import 'package:flutter/material.dart';

import '../layouts/nav_destinations.dart';
import '../theme/app_theme.dart';
import 'dialogs.dart';

/// 250px desktop navigation with the Emergency Support box pinned to the bottom.
class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.selected, required this.onSelect, this.alertCount = 0});
  final int selected;
  final ValueChanged<int> onSelect;
  final int alertCount;

  @override
  Widget build(BuildContext context) => Container(
        width: 250,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(right: BorderSide(color: AppColors.border)),
        ),
        child: Column(children: [
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('NAVIGATION',
                  style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < navDestinations.length; i++)
            _NavItem(
              destination: navDestinations[i],
              active: i == selected,
              badge: navDestinations[i].label == 'Alerts' ? alertCount : 0,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          const _EmergencySupportBox(),
        ]),
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.destination, required this.active, required this.onTap, this.badge = 0});
  final NavDestination destination;
  final bool active;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => Material(
        color: active ? AppColors.brandTint : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: active ? AppColors.brand : Colors.transparent, width: 4)),
            ),
            child: Row(children: [
              Icon(active ? destination.activeIcon : destination.icon,
                  color: active ? AppColors.brand : AppColors.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(destination.label,
                    style: TextStyle(
                      color: active ? AppColors.brand : AppColors.textPrimary,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    )),
              ),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
                  child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
        ),
      );
}

class _EmergencySupportBox extends StatelessWidget {
  const _EmergencySupportBox();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.brandTint,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Material(
            color: AppColors.brand,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => showSosDialog(context),
              child: const SizedBox(
                width: 60,
                height: 60,
                child: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Emergency Support', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Tap SOS for Central 911 and Red Cross hotlines',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
      );
}
