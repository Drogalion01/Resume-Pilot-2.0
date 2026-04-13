// lib/app/shell/app_shell.dart
//
// Shell scaffold with animated Material 3 bottom navigation bar.
// Persistent across the 4 main tabs.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/router.dart';
import '../theme/premium_theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _tabs = [
    (route: Routes.dashboard, icon: Icons.grid_view_rounded, label: 'Home'),
    (route: Routes.applications, icon: Icons.work_outline_rounded, label: 'Track'),
    (route: Routes.resumeLab, icon: Icons.auto_fix_high_rounded, label: 'AI Lab'),
    (route: Routes.settings, icon: Icons.settings_outlined, label: 'Settings'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: PremiumTheme.darkBorder.withOpacity(0.5),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (i) => context.go(_tabs[i].route),
          destinations: _tabs
              .map((t) => NavigationDestination(
                    icon: Icon(t.icon),
                    label: t.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}
