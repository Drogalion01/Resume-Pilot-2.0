// lib/shared/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme/premium_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.darkBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo mark
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: PremiumTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: PremiumTheme.primary.withOpacity(0.4),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.rocket_launch_rounded,
                  color: Colors.white, size: 40),
            )
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(begin: const Offset(0.7, 0.7)),
            const SizedBox(height: 24),
            Text(
              'ResumePilot',
              style: PremiumTheme.headline2(PremiumTheme.darkTextPrimary),
            ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.3),
            const SizedBox(height: 8),
            Text(
              'Land your dream job with AI',
              style: PremiumTheme.body(PremiumTheme.darkTextSecondary),
            ).animate(delay: 400.ms).fadeIn(),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(PremiumTheme.accent),
              ),
            ).animate(delay: 600.ms).fadeIn(),
          ],
        ),
      ),
    );
  }
}
