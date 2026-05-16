// lib/features/auth/screens/magic_link_verify_screen.dart
//
// Handles the deep link: resumepilot://app/auth/verify?token=<token>
//
// This screen is navigated to when the user taps the magic link in their email.
// It shows a spinner while the token is being verified, then redirects:
//   - Success → GoRouter redirect automatically pushes to /dashboard
//   - MFA required → totp_challenge_screen
//   - Error → shows error message with a "go back" option

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/premium_theme.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';

class MagicLinkVerifyScreen extends ConsumerStatefulWidget {
  final String token;
  const MagicLinkVerifyScreen({super.key, required this.token});

  @override
  ConsumerState<MagicLinkVerifyScreen> createState() =>
      _MagicLinkVerifyScreenState();
}

class _MagicLinkVerifyScreenState
    extends ConsumerState<MagicLinkVerifyScreen> {
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    // Verify immediately on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authNotifierProvider.notifier).verifyMagicLink(widget.token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // Navigate on MFA required
    if (authState is AuthStateMFAPending && !_verified) {
      _verified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(Routes.totpChallenge,
            extra: authState.mfaToken);
      });
    }

    // GoRouter redirect handles authenticated → dashboard automatically
    // Only handle error explicitly here
    return Scaffold(
      backgroundColor: PremiumTheme.bgPrimary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _buildBody(authState),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AuthState authState) {
    if (authState is AuthStateError) {
      return _ErrorView(
        message: authState.message,
        onRetry: () => context.go(Routes.landing),
      ).animate().fadeIn();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: PremiumTheme.accent.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.description_rounded,
              color: PremiumTheme.accent, size: 40),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1.05, 1.05),
              duration: 1000.ms,
              curve: Curves.easeInOut,
            ),

        const SizedBox(height: 32),

        Text('Signing you in…',
                style: PremiumTheme.headline2(PremiumTheme.textPrimary))
            .animate()
            .fadeIn(delay: 200.ms),

        const SizedBox(height: 12),

        Text(
          'Verifying your magic link',
          style: PremiumTheme.body(PremiumTheme.textSecondary),
        ).animate().fadeIn(delay: 350.ms),

        const SizedBox(height: 40),

        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            color: PremiumTheme.accent,
            strokeWidth: 2.5,
          ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: PremiumTheme.error.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: PremiumTheme.error, size: 40),
          ),

          const SizedBox(height: 24),

          Text('Link expired or invalid',
              style: PremiumTheme.headline2(PremiumTheme.textPrimary)),

          const SizedBox(height: 12),

          Text(
            message,
            textAlign: TextAlign.center,
            style: PremiumTheme.body(PremiumTheme.textSecondary),
          ),

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: PremiumTheme.accent,
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Request a new link',
                style: PremiumTheme.body(Colors.white)
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      );
}
