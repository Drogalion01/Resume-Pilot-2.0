// lib/features/auth/screens/magic_link_screen.dart
//
// Step 1 of magic link flow:
//   - Email input form
//   - On submit: calls sendMagicLink() → backend sends the email
//   - On success: shows "Check your inbox" state with 60s resend cooldown

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/premium_theme.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/primary_button.dart';

class MagicLinkScreen extends ConsumerStatefulWidget {
  const MagicLinkScreen({super.key});

  @override
  ConsumerState<MagicLinkScreen> createState() => _MagicLinkScreenState();
}

class _MagicLinkScreenState extends ConsumerState<MagicLinkScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _sent = false;
  String? _sentEmail;

  // Resend cooldown
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailCtrl.text.trim();
    await ref.read(authNotifierProvider.notifier).sendMagicLink(email);
  }

  void _startCooldown() {
    _cooldownSeconds =
        AppConstants.magicLinkResendCooldown.inSeconds;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) t.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // Transition to "sent" view when state changes
    if (authState is AuthStateMagicLinkSent && !_sent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _sent = true;
          _sentEmail = authState.email;
        });
        _startCooldown();
      });
    }

    final isLoading = authState is AuthStateLoading;
    final error = authState is AuthStateError ? authState.message : null;

    return Scaffold(
      backgroundColor: PremiumTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: PremiumTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: 400.ms,
          child: _sent
              ? _SentView(
                  key: const ValueKey('sent'),
                  email: _sentEmail!,
                  cooldownSeconds: _cooldownSeconds,
                  onResend: _cooldownSeconds > 0
                      ? null
                      : () {
                          setState(() => _sent = false);
                          _emailCtrl.text = _sentEmail!;
                        },
                  onChangeEmail: () => setState(() {
                    _sent = false;
                    _emailCtrl.clear();
                  }),
                )
              : _InputView(
                  key: const ValueKey('input'),
                  formKey: _formKey,
                  emailCtrl: _emailCtrl,
                  isLoading: isLoading,
                  error: error,
                  onSubmit: _submit,
                ),
        ),
      ),
    );
  }
}

// ── Input View ─────────────────────────────────────────────────────────────────

class _InputView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final bool isLoading;
  final String? error;
  final VoidCallback onSubmit;

  const _InputView({
    super.key,
    required this.formKey,
    required this.emailCtrl,
    required this.isLoading,
    required this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              Text('Sign in to\nResume Pilot',
                      style: PremiumTheme.headline1(PremiumTheme.textPrimary))
                  .animate()
                  .fadeIn(delay: 50.ms)
                  .slideY(begin: 0.2),

              const SizedBox(height: 10),

              Text(
                "We'll send a magic link to your email — no password needed.",
                style: PremiumTheme.body(PremiumTheme.textSecondary),
              ).animate(delay: 150.ms).fadeIn(),

              const SizedBox(height: 36),

              if (error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: PremiumTheme.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: PremiumTheme.error.withOpacity(0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        color: PremiumTheme.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(error!,
                            style:
                                PremiumTheme.bodySmall(PremiumTheme.error))),
                  ]),
                ).animate().fadeIn().shakeX(hz: 3),
                const SizedBox(height: 20),
              ],

              Text('Email address',
                  style: PremiumTheme.label(PremiumTheme.textSecondary)),
              const SizedBox(height: 8),

              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofocus: true,
                onFieldSubmitted: (_) => onSubmit(),
                style: PremiumTheme.body(PremiumTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                  if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email';
                  return null;
                },
              ).animate(delay: 200.ms).fadeIn(),

              const SizedBox(height: 28),

              PrimaryButton(
                label: 'Send magic link',
                onTap: isLoading ? null : onSubmit,
                isLoading: isLoading,
              ).animate(delay: 300.ms).fadeIn(),
            ],
          ),
        ),
      );
}

// ── Sent View ──────────────────────────────────────────────────────────────────

class _SentView extends StatelessWidget {
  final String email;
  final int cooldownSeconds;
  final VoidCallback? onResend;
  final VoidCallback onChangeEmail;

  const _SentView({
    super.key,
    required this.email,
    required this.cooldownSeconds,
    required this.onResend,
    required this.onChangeEmail,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: PremiumTheme.accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_rounded,
                    color: PremiumTheme.accent, size: 40),
              ).animate().scale(begin: const Offset(0.5, 0.5)).fadeIn(),

              const SizedBox(height: 28),

              Text('Check your inbox',
                      style:
                          PremiumTheme.headline2(PremiumTheme.textPrimary))
                  .animate(delay: 100.ms)
                  .fadeIn()
                  .slideY(begin: 0.2),

              const SizedBox(height: 12),

              Text(
                "We've sent a sign-in link to",
                textAlign: TextAlign.center,
                style: PremiumTheme.body(PremiumTheme.textSecondary),
              ).animate(delay: 200.ms).fadeIn(),

              const SizedBox(height: 4),

              Text(
                email,
                textAlign: TextAlign.center,
                style: PremiumTheme.body(PremiumTheme.accent)
                    .copyWith(fontWeight: FontWeight.w700),
              ).animate(delay: 250.ms).fadeIn(),

              const SizedBox(height: 8),

              Text(
                'The link expires in 15 minutes and can only be used once.',
                textAlign: TextAlign.center,
                style: PremiumTheme.caption(PremiumTheme.textMuted),
              ).animate(delay: 300.ms).fadeIn(),

              const SizedBox(height: 40),

              // Resend button
              TextButton(
                onPressed: onResend,
                child: Text(
                  cooldownSeconds > 0
                      ? 'Resend link in ${cooldownSeconds}s'
                      : 'Resend link',
                  style: PremiumTheme.body(cooldownSeconds > 0
                      ? PremiumTheme.textMuted
                      : PremiumTheme.accent),
                ),
              ).animate(delay: 350.ms).fadeIn(),

              const SizedBox(height: 8),

              TextButton(
                onPressed: onChangeEmail,
                child: Text('Use a different email',
                    style: PremiumTheme.body(PremiumTheme.textSecondary)),
              ).animate(delay: 400.ms).fadeIn(),
            ],
          ),
        ),
      );
}
