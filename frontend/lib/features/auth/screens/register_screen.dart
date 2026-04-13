// lib/features/auth/screens/register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/premium_theme.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../shared/widgets/primary_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).register(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          fullName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        );
  }

  Future<void> _googleSignIn() async {
    await ref.read(authNotifierProvider.notifier).loginWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthStateLoading;
    final error = authState is AuthStateError ? authState.message : null;

    return Scaffold(
      backgroundColor: PremiumTheme.darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                GestureDetector(
                  onTap: () => context.go(Routes.welcome),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PremiumTheme.darkCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: PremiumTheme.darkBorder),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: PremiumTheme.darkTextPrimary, size: 20),
                  ),
                ).animate().fadeIn(),

                const SizedBox(height: 36),

                Text('Create account', style: PremiumTheme.headline2(PremiumTheme.darkTextPrimary))
                    .animate(delay: 100.ms).fadeIn().slideY(begin: 0.2),
                const SizedBox(height: 8),
                Text('Join thousands of job seekers using ResumePilot.',
                    style: PremiumTheme.body(PremiumTheme.darkTextSecondary))
                    .animate(delay: 150.ms).fadeIn(),

                const SizedBox(height: 32),

                // Error banner
                if (error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: PremiumTheme.error.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PremiumTheme.error.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: PremiumTheme.error, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(error,
                              style: PremiumTheme.bodySmall(PremiumTheme.error)),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().shakeX(hz: 3),
                  const SizedBox(height: 20),
                ],

                // Full name (optional)
                _Label('Full name (optional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  style: PremiumTheme.body(PremiumTheme.darkTextPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Jane Smith',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ).animate(delay: 200.ms).fadeIn(),

                const SizedBox(height: 18),

                // Email
                _Label('Email address'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: PremiumTheme.body(PremiumTheme.darkTextPrimary),
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                    return null;
                  },
                ).animate(delay: 300.ms).fadeIn(),

                const SizedBox(height: 18),

                // Password
                _Label('Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  style: PremiumTheme.body(PremiumTheme.darkTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Min. 8 characters',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: GestureDetector(
                      onTap: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      child: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 8)
                      return 'Password must be at least 8 characters';
                    return null;
                  },
                ).animate(delay: 350.ms).fadeIn(),

                const SizedBox(height: 18),

                // Confirm password
                _Label('Confirm password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  style: PremiumTheme.body(PremiumTheme.darkTextPrimary),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: GestureDetector(
                      onTap: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      child: Icon(_obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                    ),
                  ),
                  validator: (v) {
                    if (v != _passwordCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ).animate(delay: 400.ms).fadeIn(),

                const SizedBox(height: 32),

                PrimaryButton(
                  label: 'Create Account',
                  onTap: isLoading ? null : _submit,
                  isLoading: isLoading,
                ).animate(delay: 450.ms).fadeIn(),

                const SizedBox(height: 24),

                Row(
                  children: [
                    const Expanded(child: Divider(color: PremiumTheme.darkBorder)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('or',
                          style: PremiumTheme.bodySmall(PremiumTheme.darkTextTertiary)),
                    ),
                    const Expanded(child: Divider(color: PremiumTheme.darkBorder)),
                  ],
                ).animate(delay: 500.ms).fadeIn(),

                const SizedBox(height: 20),

                _GoogleButton(onTap: isLoading ? null : _googleSignIn)
                    .animate(delay: 550.ms).fadeIn(),

                const SizedBox(height: 32),

                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Already have an account? ',
                          style: PremiumTheme.body(PremiumTheme.darkTextSecondary)),
                      GestureDetector(
                        onTap: () => context.go(Routes.login),
                        child: Text('Sign In',
                            style: PremiumTheme.body(PremiumTheme.accent)
                                .copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ).animate(delay: 600.ms).fadeIn(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: PremiumTheme.bodySmall(PremiumTheme.darkTextSecondary)
            .copyWith(fontWeight: FontWeight.w600),
      );
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _GoogleButton({this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: PremiumTheme.darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PremiumTheme.darkBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF4285F4), Color(0xFF34A853)],
                  ),
                ),
                child: const Icon(Icons.g_mobiledata, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Text('Continue with Google',
                  style: PremiumTheme.body(PremiumTheme.darkTextPrimary)
                      .copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
}
