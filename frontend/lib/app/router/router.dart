// lib/app/router/router.dart
//
// GoRouter configuration with auth-guard redirect.
// Shell route = 4 bottom-nav tabs.
// Full-screen routes push on top without the nav bar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../shared/screens/splash_screen.dart';
import '../shell/app_shell.dart';

// ── Route names (type-safe navigation) ───────────────────────────────────────

class Routes {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/';
  static const applications = '/applications';
  static const resumeLab = '/resume-lab';
  static const settings = '/settings';
  // Future full-screen routes
  static const upload = '/upload';
  static const profile = '/profile';
}

// ── Provider ──────────────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: _AuthStateListenable(ref),
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isAuthRoute = [
        Routes.splash,
        Routes.welcome,
        Routes.login,
        Routes.register,
      ].contains(location);

      switch (authState) {
        case AuthStateInitial() || AuthStateLoading():
          return location == Routes.splash ? null : Routes.splash;

        case AuthStateAuthenticated(user: final user):
          if (isAuthRoute) {
            return Routes.dashboard;
          }
          return null;

        case AuthStateUnauthenticated() || AuthStateError():
          if (!isAuthRoute) return Routes.welcome;
          return null;
      }
    },
    routes: [
      // ── Splash ────────────────────────────────────────────────────────────
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),

      // ── Auth (full-screen, no shell) ──────────────────────────────────────
      GoRoute(path: Routes.welcome, builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, __) => const RegisterScreen()),

      // ── App shell with bottom nav ─────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: Routes.dashboard,
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: Routes.applications,
            builder: (_, __) => const PlaceholderScreen(label: 'Applications'),
          ),
          GoRoute(
            path: Routes.resumeLab,
            builder: (_, __) => const PlaceholderScreen(label: 'Resume Lab'),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

// ── _AuthStateListenable: triggers GoRouter refresh on auth state change ──────

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    ref.listen<AuthState>(authNotifierProvider, (_, __) => notifyListeners());
  }
}

// ── Placeholder for Phase 2+ screens ─────────────────────────────────────────

class PlaceholderScreen extends StatelessWidget {
  final String label;
  const PlaceholderScreen({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Text(label,
              style: Theme.of(context).textTheme.headlineMedium),
        ),
      );
}
