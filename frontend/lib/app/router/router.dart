// lib/app/router/router.dart
//
// GoRouter configuration with:
//   - Auth-guard redirect (unauthenticated → landing, mfaPending → totp)
//   - Deep link handling via app_links:
//       resumepilot://app/auth/verify?token=   (magic link)
//       resumepilot://app/auth/callback/{provider}?code=&state=   (OAuth — handled in auth_notifier)
//   - Shell route = 4 bottom-nav tabs (Home, Track, Resume Lab, Settings)
//   - Full-screen routes push above the nav bar

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../features/auth/screens/landing_screen.dart';
import '../../features/auth/screens/magic_link_screen.dart';
import '../../features/auth/screens/magic_link_verify_screen.dart';
import '../../features/auth/screens/totp_challenge_screen.dart';
import '../../features/auth/screens/totp_setup_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../shared/screens/splash_screen.dart';
import '../shell/app_shell.dart';

// ── Route paths (type-safe) ────────────────────────────────────────────────────

class Routes {
  static const splash          = '/splash';
  static const landing         = '/landing';
  static const magicLink       = '/auth/magic-link';
  static const magicLinkVerify = '/auth/verify';   // deep link: ?token=
  static const totpChallenge   = '/auth/totp';
  static const totpSetup       = '/auth/totp/setup';

  // Shell tabs
  static const dashboard   = '/';
  static const applications = '/applications';
  static const resumeLab   = '/resume-lab';
  static const settings    = '/settings';

  // Full-screen routes (inside or outside shell)
  static const upload      = '/resume-lab/upload';
  static const generate    = '/resume-lab/generate';
  static const generationResult = '/resume-lab/result';
  static const applicationDetail = '/applications/detail';
}

// ── Provider ───────────────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.read(authNotifierProvider.notifier);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: _AuthStateListenable(ref),
    redirect: (context, state) {
      final location = state.matchedLocation;
      final authState = ref.read(authNotifierProvider);

      final isAuthRoute = [
        Routes.splash,
        Routes.landing,
        Routes.magicLink,
        Routes.magicLinkVerify,
        Routes.totpChallenge,
      ].any((r) => location.startsWith(r));

      switch (authState) {
        case AuthStateInitial() || AuthStateLoading():
          return location == Routes.splash ? null : Routes.splash;

        case AuthStateMFAPending():
          if (location == Routes.totpChallenge) return null;
          return Routes.totpChallenge;

        case AuthStateMagicLinkSent():
          if (location == Routes.magicLink) return null;
          return Routes.magicLink;

        case AuthStateAuthenticated():
          if (isAuthRoute) return Routes.dashboard;
          return null;

        case AuthStateUnauthenticated() || AuthStateError():
          if (!isAuthRoute) return Routes.landing;
          return null;
      }
    },
    routes: [
      // ── Splash ──────────────────────────────────────────────────────────────
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),

      // ── Auth screens (full-screen, no shell) ─────────────────────────────
      GoRoute(path: Routes.landing,   builder: (_, __) => const LandingScreen()),
      GoRoute(path: Routes.magicLink, builder: (_, __) => const MagicLinkScreen()),

      // Magic link deep link: /auth/verify?token=<token>
      GoRoute(
        path: Routes.magicLinkVerify,
        builder: (_, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return MagicLinkVerifyScreen(token: token);
        },
      ),

      // TOTP challenge — receives mfaToken via extras
      GoRoute(
        path: Routes.totpChallenge,
        builder: (_, state) {
          final mfaToken = state.extra as String?;
          // If extra is null, fall back to the MFAPending state value
          return TotpChallengeScreen(mfaToken: mfaToken ?? '');
        },
      ),

      // TOTP setup — push from settings
      GoRoute(
        path: Routes.totpSetup,
        builder: (_, __) => const TotpSetupScreen(),
      ),

      // ── App shell with bottom navigation ─────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: Routes.dashboard,
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: Routes.applications,
            builder: (_, __) => const PlaceholderScreen(label: 'Applications', icon: Icons.work_outline_rounded),
          ),
          GoRoute(
            path: Routes.resumeLab,
            builder: (_, __) => const PlaceholderScreen(label: 'Resume Lab', icon: Icons.description_outlined),
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

// ── _AuthStateListenable ───────────────────────────────────────────────────────

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    ref.listen<AuthState>(authNotifierProvider, (_, __) => notifyListeners());
  }
}

// ── Placeholder (while Resume Lab / Applications screens are built) ───────────

class PlaceholderScreen extends StatelessWidget {
  final String label;
  final IconData icon;
  const PlaceholderScreen({super.key, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(height: 16),
              Text(label, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('Coming soon', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
}
