// lib/features/auth/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/premium_theme.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../shared/widgets/primary_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).login(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
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

                // Back button
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

                // Heading
                Text('Welcome back', style: PremiumTheme.headline2(PremiumTheme.darkTextPrimary))
                    .animate(delay: 100.ms).fadeIn().slideY(begin: 0.2),
                const SizedBox(height: 8),
                Text('Sign in to continue your job search journey.',
                    style: PremiumTheme.body(PremiumTheme.darkTextSecondary))
                    .animate(delay: 200.ms).fadeIn(),

                const SizedBox(height: 36),

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

                // Email field
                _InputLabel('Email address'),
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
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ).animate(delay: 300.ms).fadeIn(),

                const SizedBox(height: 20),

                // Password field
                _InputLabel('Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  style: PremiumTheme.body(PremiumTheme.darkTextPrimary),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                      child: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    return null;
                  },
                ).animate(delay: 400.ms).fadeIn(),

                const SizedBox(height: 12),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {}, // TODO: forgot password screen
                    child: Text('Forgot password?',
                        style: PremiumTheme.bodySmall(PremiumTheme.accent)),
                  ),
                ).animate(delay: 450.ms).fadeIn(),

                const SizedBox(height: 24),

                // Sign in button
                PrimaryButton(
                  label: 'Sign In',
                  onTap: isLoading ? null : _submit,
                  isLoading: isLoading,
                ).animate(delay: 500.ms).fadeIn(),

                const SizedBox(height: 24),

                // Divider
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
                ).animate(delay: 550.ms).fadeIn(),

                const SizedBox(height: 20),

                // Google sign-in
                _GoogleButton(onTap: isLoading ? null : _googleSignIn)
                    .animate(delay: 600.ms).fadeIn(),

                const SizedBox(height: 32),

                // Register link
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Don't have an account? ",
                          style: PremiumTheme.body(PremiumTheme.darkTextSecondary)),
                      GestureDetector(
                        onTap: () => context.go(Routes.register),
                        child: Text('Sign Up',
                            style: PremiumTheme.body(PremiumTheme.accent)
                                .copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ).animate(delay: 650.ms).fadeIn(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InputLabel extends StatelessWidget {
  final String text;
  const _InputLabel(this.text);

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
              // Google G icon (simple colored circle placeholder)
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
