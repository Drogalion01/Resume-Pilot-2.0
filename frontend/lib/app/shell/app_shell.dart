// lib/app/shell/app_shell.dart
//
// Shell scaffold with animated Material 3 bottom navigation bar.
// Persistent across the 4 main tabs.
//
// Also owns the app_links deep link listener — any resumepilot:// URI
// that arrives while the app is in foreground is routed here.
// Cold-start deep links (app was closed) are handled by GoRouter's
// initialLocation which reads the launch URI from app_links.

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/router.dart';
import '../theme/premium_theme.dart';
import '../../features/settings/providers/subscription_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _tabs = [
    (route: Routes.dashboard,    icon: Icons.grid_view_rounded,     label: 'Home'),
    (route: Routes.applications, icon: Icons.work_outline_rounded,   label: 'Track'),
    (route: Routes.resumeLab,    icon: Icons.auto_fix_high_rounded,  label: 'AI Lab'),
    (route: Routes.settings,     icon: Icons.settings_outlined,      label: 'Settings'),
  ];

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _linkSub = _appLinks.uriLinkStream.listen(_handleIncomingLink);
    // Initialize Paddle.js early (web only) so checkout is ready before Settings opens
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(paddleInitProvider);
      });
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  void _handleIncomingLink(Uri uri) {
    if (!mounted) return;
    // resumepilot://app/auth/verify?token=<token>
    if (uri.host == 'app' && uri.pathSegments.first == 'auth') {
      final path = '/${uri.pathSegments.join('/')}';
      final query = uri.queryParameters.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      context.go(query.isEmpty ? path : '$path?$query');
    }
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (location == _tabs[i].route ||
          (i != 0 && location.startsWith(_tabs[i].route))) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    return Scaffold(
      body: widget.child,
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
