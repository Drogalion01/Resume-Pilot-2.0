// lib/features/auth/screens/landing_screen.dart
//
// Entry point for unauthenticated users.
// Offers: magic link (primary) + OAuth: Google, GitHub, LinkedIn.
// No passwords ever.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/premium_theme.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';

class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthStateLoading;
    final error = authState is AuthStateError ? authState.message : null;

    return Scaffold(
      backgroundColor: PremiumTheme.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // ── Logo & Brand ───────────────────────────────────────────
                _LogoBrand()
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: -0.2, curve: Curves.easeOut),

                const SizedBox(height: 56),

                // ── Tagline ────────────────────────────────────────────────
                Text(
                  'Land your dream job\nwith AI-tailored resumes',
                  textAlign: TextAlign.center,
                  style: PremiumTheme.headline2(PremiumTheme.textPrimary),
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.15),

                const SizedBox(height: 12),

                Text(
                  'Upload your master resume once. Generate perfectly tailored versions for every application.',
                  textAlign: TextAlign.center,
                  style: PremiumTheme.body(PremiumTheme.textSecondary),
                ).animate(delay: 350.ms).fadeIn(),

                const SizedBox(height: 48),

                // ── Error banner ───────────────────────────────────────────
                if (error != null) ...[
                  _ErrorBanner(message: error).animate().fadeIn().shakeX(hz: 3),
                  const SizedBox(height: 20),
                ],

                // ── Primary CTA: Magic Link ────────────────────────────────
                _PrimaryCTA(isLoading: isLoading)
                    .animate(delay: 450.ms)
                    .fadeIn()
                    .slideY(begin: 0.15),

                const SizedBox(height: 24),

                // ── Divider ────────────────────────────────────────────────
                _Divider().animate(delay: 550.ms).fadeIn(),

                const SizedBox(height: 20),

                // ── OAuth buttons ──────────────────────────────────────────
                ..._oauthButtons(ref, isLoading)
                    .indexed
                    .map((entry) => entry.$2
                        .animate(delay: (600 + entry.$1 * 80).ms)
                        .fadeIn()
                        .slideX(begin: -0.05)),

                const SizedBox(height: 48),

                // ── Terms ──────────────────────────────────────────────────
                Text(
                  'By continuing, you agree to our Terms of Service and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: PremiumTheme.caption(PremiumTheme.textMuted),
                ).animate(delay: 900.ms).fadeIn(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _oauthButtons(WidgetRef ref, bool isLoading) => [
        _OAuthButton(
          label: 'Continue with Google',
          iconPath: 'google',
          color: const Color(0xFF4285F4),
          onTap: isLoading
              ? null
              : () => ref.read(authNotifierProvider.notifier).oauthAuthorize('google'),
        ),
        const SizedBox(height: 12),
        _OAuthButton(
          label: 'Continue with GitHub',
          iconPath: 'github',
          color: const Color(0xFFE6EDF3),
          onTap: isLoading
              ? null
              : () => ref.read(authNotifierProvider.notifier).oauthAuthorize('github'),
        ),
        const SizedBox(height: 12),
        _OAuthButton(
          label: 'Continue with LinkedIn',
          iconPath: 'linkedin',
          color: const Color(0xFF0A66C2),
          onTap: isLoading
              ? null
              : () => ref.read(authNotifierProvider.notifier).oauthAuthorize('linkedin'),
        ),
        const SizedBox(height: 12),
      ];
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _LogoBrand extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [PremiumTheme.accent, Color(0xFF5B4FE8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: PremiumTheme.accent.withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.description_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 14),
        Text('Resume Pilot',
            style: PremiumTheme.headline2(PremiumTheme.textPrimary)
                .copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ]);
}

class _PrimaryCTA extends ConsumerWidget {
  final bool isLoading;
  const _PrimaryCTA({required this.isLoading});

  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
        onTap: isLoading ? null : () => context.push(Routes.magicLink),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [PremiumTheme.accent, Color(0xFF5B4FE8)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: PremiumTheme.accent.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading) ...[
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)),
              ] else ...[
                const Icon(Icons.email_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('Continue with email',
                    style: PremiumTheme.body(Colors.white)
                        .copyWith(fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [
        const Expanded(
            child: Divider(color: PremiumTheme.bgCard, thickness: 1.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('or sign in with', style: PremiumTheme.caption(PremiumTheme.textMuted)),
        ),
        const Expanded(
            child: Divider(color: PremiumTheme.bgCard, thickness: 1.5)),
      ]);
}

class _OAuthButton extends StatelessWidget {
  final String label;
  final String iconPath;
  final Color color;
  final VoidCallback? onTap;

  const _OAuthButton({
    required this.label,
    required this.iconPath,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: 200.ms,
          opacity: onTap == null ? 0.5 : 1.0,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: PremiumTheme.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PremiumTheme.bgSecondary, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ProviderIcon(provider: iconPath, color: color),
                const SizedBox(width: 12),
                Text(label,
                    style: PremiumTheme.body(PremiumTheme.textPrimary)
                        .copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      );
}

class _ProviderIcon extends StatelessWidget {
  final String provider;
  final Color color;
  const _ProviderIcon({required this.provider, required this.color});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (provider) {
      case 'google':
        icon = Icons.g_mobiledata_rounded;
      case 'github':
        icon = Icons.code_rounded;
      case 'linkedin':
        icon = Icons.work_outline_rounded;
      default:
        icon = Icons.login_rounded;
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PremiumTheme.error.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PremiumTheme.error.withOpacity(0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: PremiumTheme.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: PremiumTheme.bodySmall(PremiumTheme.error))),
        ]),
      );
}
