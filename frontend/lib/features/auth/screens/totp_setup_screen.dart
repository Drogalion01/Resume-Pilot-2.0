// lib/features/auth/screens/totp_setup_screen.dart
//
// TOTP 2FA setup — shown in Settings → Security → Enable 2FA.
//
// Flow:
//   1. GET /auth/totp/setup → {secret, otpauth_uri, backup_codes}
//   2. Display QR code + raw secret for manual entry
//   3. User enters 6-digit code to confirm they scanned correctly
//   4. POST /auth/totp/setup/confirm → enables TOTP
//   5. Show backup codes (one-time reveal) — user must acknowledge

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/premium_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/primary_button.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

final _totpSetupDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final res = await client.dio.get('/auth/totp/setup');
  return res.data as Map<String, dynamic>;
});

// ── Screen ─────────────────────────────────────────────────────────────────────

class TotpSetupScreen extends ConsumerStatefulWidget {
  const TotpSetupScreen({super.key});

  @override
  ConsumerState<TotpSetupScreen> createState() => _TotpSetupScreenState();
}

class _TotpSetupScreenState extends ConsumerState<TotpSetupScreen> {
  final _codeCtrl = TextEditingController();
  bool _confirming = false;
  bool _confirmed = false;
  String? _error;
  List<String> _backupCodes = [];

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm(String secret) async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6 || int.tryParse(code) == null) {
      setState(() => _error = 'Enter the 6-digit code from your authenticator app');
      return;
    }

    setState(() { _confirming = true; _error = null; });

    try {
      final client = ref.read(apiClientProvider);
      final res = await client.dio.post(
        '/auth/totp/setup/confirm',
        queryParameters: {'secret': secret, 'code': code},
      );

      // Backend returns backup codes on confirm
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _confirming = false;
        _confirmed = true;
        _backupCodes = (data['backup_codes'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
      });
    } catch (e) {
      setState(() {
        _confirming = false;
        _error = 'Invalid code — make sure your device clock is accurate';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final setupAsync = ref.watch(_totpSetupDataProvider);

    return Scaffold(
      backgroundColor: PremiumTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Set up two-factor auth',
            style: PremiumTheme.body(PremiumTheme.textPrimary)
                .copyWith(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: PremiumTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: setupAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: PremiumTheme.accent)),
        error: (e, _) => Center(
            child: Text('Failed to load setup data',
                style: PremiumTheme.body(PremiumTheme.error))),
        data: (data) {
          final secret     = data['secret'] as String;
          final otpauthUri = data['otpauth_uri'] as String;

          if (_confirmed) {
            return _BackupCodesView(
              codes: _backupCodes,
              onDone: () => context.pop(),
            );
          }

          return _SetupView(
            secret: secret,
            otpauthUri: otpauthUri,
            codeCtrl: _codeCtrl,
            confirming: _confirming,
            error: _error,
            onConfirm: () => _confirm(secret),
          );
        },
      ),
    );
  }
}

// ── Setup view: QR + code entry ────────────────────────────────────────────────

class _SetupView extends StatelessWidget {
  final String secret;
  final String otpauthUri;
  final TextEditingController codeCtrl;
  final bool confirming;
  final String? error;
  final VoidCallback onConfirm;

  const _SetupView({
    required this.secret,
    required this.otpauthUri,
    required this.codeCtrl,
    required this.confirming,
    required this.error,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '1. Scan this QR code with your authenticator app\n   (Google Authenticator, Authy, 1Password, etc.)',
              style: PremiumTheme.body(PremiumTheme.textSecondary),
            ).animate().fadeIn(),

            const SizedBox(height: 24),

            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: otpauthUri,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ).animate(delay: 100.ms).fadeIn().scale(begin: const Offset(0.9, 0.9)),

            const SizedBox(height: 16),

            Text('Or enter the code manually:',
                style: PremiumTheme.caption(PremiumTheme.textMuted)),
            const SizedBox(height: 6),

            // Manual secret key
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: secret));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Secret copied to clipboard')),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: PremiumTheme.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: PremiumTheme.accent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      secret.replaceAllMapped(
                          RegExp(r'.{4}'), (m) => '${m[0]} '),
                      style: PremiumTheme.body(PremiumTheme.accent)
                          .copyWith(
                              fontFamily: 'monospace', letterSpacing: 2),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy_rounded,
                        color: PremiumTheme.accent, size: 16),
                  ],
                ),
              ),
            ).animate(delay: 150.ms).fadeIn(),

            const SizedBox(height: 32),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '2. Enter the 6-digit code shown in your app to confirm',
                style: PremiumTheme.body(PremiumTheme.textSecondary),
              ).animate(delay: 200.ms).fadeIn(),
            ),

            const SizedBox(height: 12),

            if (error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PremiumTheme.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PremiumTheme.error.withOpacity(0.4)),
                ),
                child: Text(error!,
                    style: PremiumTheme.bodySmall(PremiumTheme.error)),
              ).animate().fadeIn().shakeX(hz: 3),
              const SizedBox(height: 12),
            ],

            TextFormField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              autofocus: true,
              onFieldSubmitted: (_) => onConfirm(),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: PremiumTheme.headline2(PremiumTheme.textPrimary)
                  .copyWith(letterSpacing: 10),
              decoration: const InputDecoration(
                hintText: '000000',
                counterText: '',
              ),
            ).animate(delay: 250.ms).fadeIn(),

            const SizedBox(height: 28),

            PrimaryButton(
              label: 'Enable two-factor auth',
              onTap: confirming ? null : onConfirm,
              isLoading: confirming,
            ).animate(delay: 300.ms).fadeIn(),
          ],
        ),
      );
}

// ── Backup codes view ──────────────────────────────────────────────────────────

class _BackupCodesView extends StatefulWidget {
  final List<String> codes;
  final VoidCallback onDone;
  const _BackupCodesView({required this.codes, required this.onDone});

  @override
  State<_BackupCodesView> createState() => _BackupCodesViewState();
}

class _BackupCodesViewState extends State<_BackupCodesView> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: PremiumTheme.success.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: PremiumTheme.success, size: 40),
            ).animate().scale(begin: const Offset(0.5, 0.5)).fadeIn(),

            const SizedBox(height: 20),

            Text('Two-factor auth enabled!',
                    style:
                        PremiumTheme.headline2(PremiumTheme.textPrimary))
                .animate(delay: 100.ms)
                .fadeIn(),

            const SizedBox(height: 12),

            Text(
              'Save these backup codes somewhere safe. Each code can only be used once. If you lose your authenticator app, you\'ll need these.',
              textAlign: TextAlign.center,
              style: PremiumTheme.body(PremiumTheme.textSecondary),
            ).animate(delay: 200.ms).fadeIn(),

            const SizedBox(height: 24),

            // Backup codes grid
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: PremiumTheme.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: PremiumTheme.accent.withOpacity(0.2)),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: widget.codes
                    .map((code) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: PremiumTheme.bgSecondary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(code,
                              style: PremiumTheme.body(PremiumTheme.accent)
                                  .copyWith(
                                      fontFamily: 'monospace',
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w700)),
                        ))
                    .toList(),
              ),
            ).animate(delay: 300.ms).fadeIn(),

            const SizedBox(height: 16),

            // Copy all button
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(
                    ClipboardData(text: widget.codes.join('\n')));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Backup codes copied to clipboard')),
                );
              },
              icon: const Icon(Icons.copy_rounded, color: PremiumTheme.accent),
              label: Text('Copy all codes',
                  style: PremiumTheme.body(PremiumTheme.accent)),
            ).animate(delay: 350.ms).fadeIn(),

            const SizedBox(height: 24),

            // Acknowledgement checkbox
            CheckboxListTile(
              value: _acknowledged,
              onChanged: (v) =>
                  setState(() => _acknowledged = v ?? false),
              activeColor: PremiumTheme.accent,
              title: Text(
                'I have saved my backup codes in a safe place',
                style: PremiumTheme.body(PremiumTheme.textPrimary),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ).animate(delay: 400.ms).fadeIn(),

            const SizedBox(height: 20),

            PrimaryButton(
              label: 'Done',
              onTap: _acknowledged ? widget.onDone : null,
            ).animate(delay: 450.ms).fadeIn(),
          ],
        ),
      );
}
