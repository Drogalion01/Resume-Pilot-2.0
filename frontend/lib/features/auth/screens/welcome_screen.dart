// lib/features/auth/screens/welcome_screen.dart
//
// Hero landing screen — first thing new users see.
// Animated gradient background with floating orbs, brand mark, CTAs.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/premium_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: PremiumTheme.darkBg,
      body: Stack(
        children: [
          // ── Background orbs ──────────────────────────────────────────────
          _Orb(color: PremiumTheme.primary, size: 300, top: -60, left: -80)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.15, 1.15),
                  duration: 4.seconds,
                  curve: Curves.easeInOut),
          _Orb(color: PremiumTheme.primaryDark, size: 200, top: size.height * 0.3, right: -60)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.2, 1.2),
                  duration: 5.seconds,
                  curve: Curves.easeInOut),
          _Orb(color: PremiumTheme.accentPink, size: 150, bottom: 80, left: size.width * 0.2)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.3, 1.3),
                  duration: 3.5.seconds,
                  curve: Curves.easeInOut),

          // ── Content ──────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),

                  // Logo mark
                  _LogoMark()
                      .animate()
                      .fadeIn(duration: 700.ms)
                      .scale(begin: const Offset(0.6, 0.6), curve: Curves.easeOutBack),

                  const SizedBox(height: 32),

                  // Headline
                  Text(
                    'Land your\ndream job\nwith AI.',
                    style: PremiumTheme.headline1(PremiumTheme.darkTextPrimary).copyWith(
                      height: 1.15,
                    ),
                  ).animate(delay: 200.ms).fadeIn(duration: 600.ms).slideX(begin: -0.1),

                  const SizedBox(height: 16),

                  // Subheadline
                  Text(
                    'Analyse your resume, get AI-powered improvements,\nand track every application — all in one place.',
                    style: PremiumTheme.body(PremiumTheme.darkTextSecondary).copyWith(height: 1.6),
                  ).animate(delay: 400.ms).fadeIn(),

                  const Spacer(flex: 3),

                  // Feature pills
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _FeaturePill(icon: Icons.insights_rounded, label: 'ATS Score'),
                      _FeaturePill(icon: Icons.auto_fix_high_rounded, label: 'AI Rewrites'),
                      _FeaturePill(icon: Icons.track_changes_rounded, label: 'Job Tracker'),
                      _FeaturePill(icon: Icons.calendar_month_rounded, label: 'Interviews'),
                    ],
                  ).animate(delay: 600.ms).fadeIn().slideY(begin: 0.2),

                  const Spacer(flex: 2),

                  // CTAs
                  _GradientButton(
                    label: 'Get Started — It\'s Free',
                    onTap: () => context.go(Routes.register),
                  ).animate(delay: 800.ms).fadeIn().slideY(begin: 0.3),

                  const SizedBox(height: 14),

                  // Sign in link
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: PremiumTheme.body(PremiumTheme.darkTextSecondary),
                        ),
                        GestureDetector(
                          onTap: () => context.go(Routes.login),
                          child: Text(
                            'Sign In',
                            style: PremiumTheme.body(PremiumTheme.accent).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate(delay: 900.ms).fadeIn(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  final double? top, bottom, left, right;

  const _Orb({
    required this.color,
    required this.size,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  @override
  Widget build(BuildContext context) => Positioned(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withOpacity(0.18), color.withOpacity(0)],
            ),
          ),
        ),
      );
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: PremiumTheme.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: PremiumTheme.primary.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Text(
            'ResumePilot',
            style: PremiumTheme.headline3(PremiumTheme.darkTextPrimary),
          ),
        ],
      );
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: PremiumTheme.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PremiumTheme.darkBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: PremiumTheme.accent, size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: PremiumTheme.bodySmall(PremiumTheme.darkTextSecondary)),
          ],
        ),
      );
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GradientButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: PremiumTheme.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: PremiumTheme.primary.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: PremiumTheme.body(Colors.white).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
}
