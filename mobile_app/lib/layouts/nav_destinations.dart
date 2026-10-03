import 'package:flutter/material.dart';

class NavDestination {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const NavDestination(this.label, this.icon, this.activeIcon);
}

const navDestinations = <NavDestination>[
  NavDestination('Home', Icons.home_outlined, Icons.home),
  NavDestination('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
  NavDestination('Prepare', Icons.inventory_2_outlined, Icons.inventory_2),
  NavDestination('Alerts', Icons.notifications_active_outlined, Icons.notifications_active),
  NavDestination('Advice', Icons.help_outline, Icons.help),
];
