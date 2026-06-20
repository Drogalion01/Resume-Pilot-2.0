// lib/features/settings/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/premium_theme.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../shared/providers/theme_provider.dart';
import '../providers/session_provider.dart';
import 'package:intl/intl.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;

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

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
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
                child: Icon(icon, color: PremiumTheme.accent, size: 18),
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
