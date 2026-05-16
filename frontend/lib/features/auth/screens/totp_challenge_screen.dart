// lib/features/auth/screens/totp_challenge_screen.dart
//
// TOTP 2FA challenge — shown when user has totp_enabled = true.
// Accepts either a 6-digit TOTP code or an 8-character backup code.
//
// Receives [mfaToken] (short-lived JWT, scope=mfa_pending, 5 min) via route extras.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/premium_theme.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../shared/widgets/primary_button.dart';

class TotpChallengeScreen extends ConsumerStatefulWidget {
  final String mfaToken;
  const TotpChallengeScreen({super.key, required this.mfaToken});

  @override
  ConsumerState<TotpChallengeScreen> createState() =>
      _TotpChallengeScreenState();
}

class _TotpChallengeScreenState extends ConsumerState<TotpChallengeScreen> {
  final _codeCtrl = TextEditingController();
  bool _useBackupCode = false;
  String? _localError;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim().replaceAll(' ', '');

    // Basic client-side validation
    if (_useBackupCode) {
      if (code.length != 8) {
        setState(() => _localError = 'Backup codes are 8 characters long');
        return;
      }
    } else {
      if (code.length != 6 || int.tryParse(code) == null) {
        setState(() => _localError = 'Enter the 6-digit code from your authenticator app');
        return;
      }
    }

    setState(() => _localError = null);
    await ref
        .read(authNotifierProvider.notifier)
        .verifyTotp(widget.mfaToken, code);

    // If state is still MFAPending, auth failed — show error
    final state = ref.read(authNotifierProvider);
    if (state is AuthStateMFAPending) {
      setState(() => _localError = 'Invalid code. Please try again.');
      _codeCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthStateLoading;

    return Scaffold(
      backgroundColor: PremiumTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: PremiumTheme.textPrimary),
          onPressed: () => context.go(Routes.landing),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Icon ────────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: PremiumTheme.accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.security_rounded,
                      color: PremiumTheme.accent, size: 36),
                ),
              ).animate().scale(begin: const Offset(0.7, 0.7)).fadeIn(),

              const SizedBox(height: 28),

              // ── Heading ─────────────────────────────────────────────────
              Center(
                child: Text('Two-factor authentication',
                        style:
                            PremiumTheme.headline2(PremiumTheme.textPrimary))
                    .animate(delay: 100.ms)
                    .fadeIn()
                    .slideY(begin: 0.15),
              ),

              const SizedBox(height: 8),

              Center(
                child: Text(
                  _useBackupCode
                      ? 'Enter one of your 8-character backup codes.'
                      : 'Enter the 6-digit code from your authenticator app.',
                  textAlign: TextAlign.center,
                  style: PremiumTheme.body(PremiumTheme.textSecondary),
                ).animate(delay: 200.ms).fadeIn(),
              ),

              const SizedBox(height: 36),

              // ── Error ────────────────────────────────────────────────────
              if (_localError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: PremiumTheme.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: PremiumTheme.error.withOpacity(0.4)),
                  ),
                  child: Text(_localError!,
                      style: PremiumTheme.bodySmall(PremiumTheme.error)),
                ).animate().fadeIn().shakeX(hz: 3),
                const SizedBox(height: 20),
              ],

              // ── Code input ──────────────────────────────────────────────
              Text(
                _useBackupCode ? 'Backup code' : 'Authentication code',
                style: PremiumTheme.label(PremiumTheme.textSecondary),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _codeCtrl,
                keyboardType: _useBackupCode
                    ? TextInputType.text
                    : TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: _useBackupCode ? 8 : 6,
                autofocus: true,
                onFieldSubmitted: (_) => _verify(),
                inputFormatters: [
                  if (!_useBackupCode)
                    FilteringTextInputFormatter.digitsOnly,
                  if (_useBackupCode)
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9]')),
                  UpperCaseTextFormatter(),
                ],
                style: PremiumTheme.headline2(PremiumTheme.textPrimary)
                    .copyWith(letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: _useBackupCode ? 'XXXXXXXX' : '000000',
                  counterText: '',
                ),
              ).animate(delay: 250.ms).fadeIn(),

              const SizedBox(height: 32),

              PrimaryButton(
                label: 'Verify',
                onTap: isLoading ? null : _verify,
                isLoading: isLoading,
              ).animate(delay: 300.ms).fadeIn(),

              const SizedBox(height: 20),

              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _useBackupCode = !_useBackupCode;
                    _codeCtrl.clear();
                    _localError = null;
                  }),
                  child: Text(
                    _useBackupCode
                        ? 'Use authenticator app instead'
                        : 'Use a backup code instead',
                    style: PremiumTheme.body(PremiumTheme.accent),
                  ),
                ).animate(delay: 350.ms).fadeIn(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Forces input to uppercase — used for backup codes.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
