import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/premium_theme.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';

class OAuthCallbackScreen extends ConsumerStatefulWidget {
  final String provider;
  final String code;
  final String callbackState;

  const OAuthCallbackScreen({
    super.key,
    required this.provider,
    required this.code,
    required this.callbackState,
  });

  @override
  ConsumerState<OAuthCallbackScreen> createState() =>
      _OAuthCallbackScreenState();
}

class _OAuthCallbackScreenState extends ConsumerState<OAuthCallbackScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authNotifierProvider.notifier).completeOAuthCallback(
            provider: widget.provider,
            code: widget.code,
            stateParam: widget.callbackState,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    if (authState is AuthStateAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(Routes.dashboard);
      });
    }

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
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: PremiumTheme.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: PremiumTheme.error, size: 40),
          ),
          const SizedBox(height: 24),
          Text('Sign-in failed',
              style: PremiumTheme.headline2(PremiumTheme.textPrimary)),
          const SizedBox(height: 12),
          Text(
            authState.message,
            textAlign: TextAlign.center,
            style: PremiumTheme.body(PremiumTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.go(Routes.landing),
            child: const Text('Back to sign in'),
          ),
        ],
      ).animate().fadeIn();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: PremiumTheme.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_open_rounded,
              color: PremiumTheme.accent, size: 40),
        )
            .animate()
            .scale(
                begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05))
            .fadeIn(),
        const SizedBox(height: 32),
        Text('Finishing sign-in…',
            style: PremiumTheme.headline2(PremiumTheme.textPrimary)),
        const SizedBox(height: 12),
        Text(
          'Connecting your ${widget.provider} account',
          textAlign: TextAlign.center,
          style: PremiumTheme.body(PremiumTheme.textSecondary),
        ),
        const SizedBox(height: 40),
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: PremiumTheme.accent,
          ),
        ),
      ],
    );
  }
}
