// lib/shared/widgets/primary_button.dart
//
// Reusable gradient primary button used across all screens.

import 'package:flutter/material.dart';
import '../../app/theme/premium_theme.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final double? width;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.width,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (isLoading || onTap == null) ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width ?? double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: (isLoading || onTap == null)
              ? LinearGradient(
                  colors: [
                    PremiumTheme.primary.withOpacity(0.5),
                    PremiumTheme.primaryDark.withOpacity(0.5),
                  ],
                )
              : PremiumTheme.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: (isLoading || onTap == null)
              ? []
              : [
                  BoxShadow(
                    color: PremiumTheme.primary.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: PremiumTheme.body(Colors.white).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
