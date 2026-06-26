// lib/features/settings/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/premium_theme.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../shared/providers/theme_provider.dart';
import '../providers/session_provider.dart';
import '../providers/subscription_provider.dart';
import 'package:intl/intl.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;

    // Initialize Paddle.js on page load
    ref.watch(paddleInitProvider);

    return Scaffold(
      backgroundColor: PremiumTheme.darkBg,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile section
          _SectionHeader('Account'),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            title: user?.displayName ?? 'Profile',
            subtitle: user?.email ?? '',
            onTap: () {}, // TODO: profile screen
          ).animate().fadeIn(),

          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.workspace_premium_outlined,
            title: 'Plan',
            subtitle: user?.plan == 'pro' ? '✨ Pro — All features unlocked' : 'Free Plan',
            onTap: () {}, // TODO: upgrade screen
          ).animate(delay: 50.ms).fadeIn(),

          const SizedBox(height: 24),

          // Appearance
          _SectionHeader('Appearance'),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Theme',
            subtitle: themeMode.name.capitalize(),
            onTap: () => _showThemePicker(context, ref),
          ).animate(delay: 100.ms).fadeIn(),

          // Billing & Subscription
          _SectionHeader('Billing & Subscription'),
          _SettingsTile(
            icon: Icons.workspace_premium_rounded,
            title: user?.isPro == true ? 'Manage Pro Subscription' : 'Upgrade to Pro',
            subtitle: user?.isPro == true
                ? 'Active until end of billing cycle'
                : 'Unlock unlimited AI generations',
            iconColor: PremiumTheme.accent,
            onTap: () => _showUpgradeSheet(context, ref, userEmail: user?.email),
          ).animate(delay: 125.ms).fadeIn(),

          const SizedBox(height: 24),

          // Notifications
          _SectionHeader('Notifications'),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Interview Reminders',
            subtitle: 'Get notified before interviews',
            trailing: Switch(
              value: true,
              onChanged: (_) {}, // TODO: settings API
              activeThumbColor: PremiumTheme.accent,
            ),
          ).animate(delay: 150.ms).fadeIn(),

          const SizedBox(height: 24),

          // Security
          _SectionHeader('Security'),
          _SettingsTile(
            icon: Icons.devices_rounded,
            title: 'Active Sessions',
            subtitle: 'Manage your logged-in devices',
            onTap: () => _showSessionsModal(context, ref),
          ).animate(delay: 175.ms).fadeIn(),

          const SizedBox(height: 24),

          // Support
          _SectionHeader('Support'),
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & FAQ',
            onTap: () {},
          ).animate(delay: 200.ms).fadeIn(),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () {},
          ).animate(delay: 225.ms).fadeIn(),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () {},
          ).animate(delay: 250.ms).fadeIn(),

          const SizedBox(height: 32),

          // Sign out
          GestureDetector(
            onTap: () => _confirmLogout(context, ref),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: PremiumTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: PremiumTheme.error.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_rounded, color: PremiumTheme.error, size: 18),
                  const SizedBox(width: 10),
                  Text('Sign Out',
                      style: PremiumTheme.body(PremiumTheme.error)
                          .copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ).animate(delay: 300.ms).fadeIn(),

          const SizedBox(height: 12),

          Center(
            child: Text('ResumePilot v2.0.0',
                style: PremiumTheme.bodySmall(PremiumTheme.darkTextTertiary)),
          ).animate(delay: 350.ms).fadeIn(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose Theme', style: PremiumTheme.headline3(PremiumTheme.darkTextPrimary)),
            const SizedBox(height: 20),
            for (final mode in ThemeMode.values)
              ListTile(
                title: Text(mode.name.capitalize(),
                    style: PremiumTheme.body(PremiumTheme.darkTextPrimary)),
                leading: Radio<ThemeMode>(
                  value: mode,
                  groupValue: ref.read(themeModeProvider),
                  activeColor: PremiumTheme.accent,
                  onChanged: (m) {
                    if (m != null) ref.read(themeModeProvider.notifier).setTheme(m);
                    Navigator.pop(context);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: PremiumTheme.darkCard,
        title: Text('Sign Out', style: PremiumTheme.headline3(PremiumTheme.darkTextPrimary)),
        content: Text('Are you sure you want to sign out?',
            style: PremiumTheme.body(PremiumTheme.darkTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authNotifierProvider.notifier).logout();
            },
            child: Text('Sign Out', style: TextStyle(color: PremiumTheme.error)),
          ),
        ],
      ),
    );
  }

  void _showUpgradeSheet(BuildContext context, WidgetRef ref,
      {String? userEmail}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpgradeSheet(userEmail: userEmail),
    );
  }

  void _showSessionsModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SessionsSheet(),
    );
  }
}

class _SessionsSheet extends ConsumerWidget {
  const _SessionsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionListProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: PremiumTheme.bgPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Active Sessions', style: PremiumTheme.headline3(PremiumTheme.textPrimary)),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          sessionsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('Failed to load: $e', style: PremiumTheme.body(PremiumTheme.error))),
            ),
            data: (sessions) {
              if (sessions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text('No active sessions found.', style: PremiumTheme.body(PremiumTheme.textSecondary))),
                );
              }
              return Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final session = sessions[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: PremiumTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PremiumTheme.darkBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.computer_rounded, color: PremiumTheme.accent, size: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.userAgent ?? 'Unknown Device',
                                  style: PremiumTheme.body(PremiumTheme.textPrimary).copyWith(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Last active: ${DateFormat('MMM d, h:mm a').format(session.lastActive)}\nIP: ${session.ipAddress ?? "Unknown"}',
                                  style: PremiumTheme.bodySmall(PremiumTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout_rounded, color: PremiumTheme.error),
                            onPressed: () => ref.read(sessionListProvider.notifier).revoke(session.familyId),
                            tooltip: 'Revoke Session',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text.toUpperCase(),
            style: PremiumTheme.label(PremiumTheme.darkTextTertiary)),
      );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: PremiumTheme.darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PremiumTheme.darkBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PremiumTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor ?? PremiumTheme.accent, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: PremiumTheme.body(PremiumTheme.darkTextPrimary)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: PremiumTheme.bodySmall(PremiumTheme.darkTextTertiary)),
                    ],
                  ],
                ),
              ),
              trailing ??
                  (onTap != null
                      ? const Icon(Icons.arrow_forward_ios_rounded,
                          color: PremiumTheme.darkTextTertiary, size: 14)
                      : const SizedBox.shrink()),
            ],
          ),
        ),
      );
}

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

// ── Upgrade / Pricing Sheet ───────────────────────────────────────────────────

class _UpgradeSheet extends ConsumerStatefulWidget {
  final String? userEmail;
  const _UpgradeSheet({this.userEmail});

  @override
  ConsumerState<_UpgradeSheet> createState() => _UpgradeSheetState();
}

class _UpgradeSheetState extends ConsumerState<_UpgradeSheet> {
  String? _selectedPriceId;

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final checkoutState = ref.watch(checkoutProvider(widget.userEmail));
    final checkoutNotifier = ref.read(checkoutProvider(widget.userEmail).notifier);

    // Dismiss on checkout success
    if (checkoutState.status == CheckoutStatus.success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pop(context);
      });
    }

    return Container(
      decoration: const BoxDecoration(
        color: PremiumTheme.bgPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: PremiumTheme.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: PremiumTheme.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upgrade to Pro',
                      style: PremiumTheme.headline3(PremiumTheme.textPrimary)),
                  Text('Unlock unlimited AI-powered resume tailoring',
                      style: PremiumTheme.bodySmall(PremiumTheme.textSecondary)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded,
                  color: PremiumTheme.textSecondary, size: 20),
            ),
          ]),
          const SizedBox(height: 24),

          // Plans
          plansAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Text('Failed to load plans: $e',
                  style: PremiumTheme.bodySmall(PremiumTheme.error)),
            ),
            data: (plans) => Column(
              children: plans.map((plan) {
                final isSelected = _selectedPriceId == plan.priceId;
                final isYearly = plan.interval == 'year';
                return GestureDetector(
                  onTap: () => setState(() => _selectedPriceId = plan.priceId),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? PremiumTheme.primary.withOpacity(0.12)
                          : PremiumTheme.darkCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? PremiumTheme.accent
                            : PremiumTheme.darkBorder,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(children: [
                      // Radio
                      Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? PremiumTheme.accent
                                : PremiumTheme.darkBorder,
                            width: 2,
                          ),
                          color: isSelected
                              ? PremiumTheme.accent
                              : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 14),

                      // Plan details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(plan.name,
                                  style: PremiumTheme.body(PremiumTheme.textPrimary)
                                      .copyWith(fontWeight: FontWeight.w600)),
                              if (isYearly) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: PremiumTheme.success.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Save 25%',
                                      style: PremiumTheme.caption(
                                          PremiumTheme.success)
                                          .copyWith(fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ]),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: plan.features
                                  .take(3)
                                  .map((f) => Text('✓ $f',
                                      style: PremiumTheme.caption(
                                          PremiumTheme.textSecondary)))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),

                      // Price
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('\$${plan.price.toStringAsFixed(2)}',
                              style: PremiumTheme.headline3(PremiumTheme.textPrimary)),
                          Text(plan.intervalLabel,
                              style: PremiumTheme.caption(PremiumTheme.textSecondary)),
                        ],
                      ),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Error banner
          if (checkoutState.status == CheckoutStatus.error &&
              checkoutState.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: PremiumTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PremiumTheme.error.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      color: PremiumTheme.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(checkoutState.error!,
                        style: PremiumTheme.bodySmall(PremiumTheme.error)),
                  ),
                ]),
              ),
            ),

          // CTA button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (_selectedPriceId == null ||
                      checkoutState.status == CheckoutStatus.loading)
                  ? null
                  : () async {
                      await checkoutNotifier.openCheckout(_selectedPriceId!);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: PremiumTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: checkoutState.status == CheckoutStatus.loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _selectedPriceId == null
                          ? 'Select a plan'
                          : 'Continue to Checkout',
                      style: PremiumTheme.body(Colors.white)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
            ),
          ),

          const SizedBox(height: 12),
          Center(
            child: Text(
              '🔒 Secure checkout powered by Paddle',
              style: PremiumTheme.caption(PremiumTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

