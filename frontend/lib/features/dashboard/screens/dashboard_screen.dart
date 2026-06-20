// lib/features/dashboard/screens/dashboard_screen.dart
//
// Phase 1 stub — shows welcome card and empty states.
// Phase 2: connected to GET /dashboard aggregated endpoint.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/premium_theme.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../providers/dashboard_provider.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;

    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: PremiumTheme.bgPrimary,
      appBar: AppBar(
        title: Image.asset('assets/images/logo.png',
            height: 28, errorBuilder: (_, __, ___) => const Text('ResumePilot')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => context.push(Routes.settings),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: PremiumTheme.primary.withOpacity(0.2),
                child: Text(
                  user?.avatarInitials ?? 'RP',
                  style: PremiumTheme.label(PremiumTheme.accent),
                ),
              ),
            ),
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.refresh(dashboardProvider.future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting
                Text(
                  'Hey, ${user?.displayName ?? 'there'} 👋',
                  style: PremiumTheme.headline3(PremiumTheme.textPrimary),
                ).animate().fadeIn().slideY(begin: 0.2),
                const SizedBox(height: 4),
                Text(
                  data.insight['message'] ?? 'Let\'s get you closer to your dream job.',
                  style: PremiumTheme.body(PremiumTheme.textSecondary),
                ).animate(delay: 100.ms).fadeIn(),

                const SizedBox(height: 28),

                // Stats row
                Row(
                  children: [
                    _StatCard(value: data.summary['total_resumes'].toString(), label: 'Resumes', icon: Icons.description_outlined),
                    const SizedBox(width: 12),
                    _StatCard(value: data.summary['total_applications'].toString(), label: 'Applied', icon: Icons.send_outlined),
                    const SizedBox(width: 12),
                    _StatCard(value: data.summary['total_interviews'].toString(), label: 'Interviews', icon: Icons.calendar_today_outlined),
                  ],
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2),

            const SizedBox(height: 28),

            // Quick actions
            Text('Quick Actions',
                style: PremiumTheme.headline3(PremiumTheme.textPrimary))
                .animate(delay: 300.ms).fadeIn(),
            const SizedBox(height: 16),

            _QuickActionCard(
              icon: Icons.upload_file_rounded,
              title: 'Upload Resume',
              subtitle: 'Add your master resume to start',
              color: PremiumTheme.primary,
              onTap: () => context.push(Routes.upload),
            ).animate(delay: 350.ms).fadeIn().slideX(begin: -0.1),

            const SizedBox(height: 12),

            _QuickActionCard(
              icon: Icons.add_circle_outline_rounded,
              title: 'Track Application',
              subtitle: 'Add a new job application',
              color: PremiumTheme.info,
              onTap: () => context.push(Routes.applications),
            ).animate(delay: 400.ms).fadeIn().slideX(begin: -0.1),

            const SizedBox(height: 12),

            _QuickActionCard(
              icon: Icons.auto_fix_high_rounded,
              title: 'AI Resume Lab',
              subtitle: 'View your tailored resumes',
              color: PremiumTheme.accent,
              onTap: () => context.push(Routes.resumeLab),
            ).animate(delay: 450.ms).fadeIn().slideX(begin: -0.1),

            const SizedBox(height: 28),

            // Empty state — upcoming interviews
            _EmptySection(
              title: 'Upcoming Interviews',
              emptyMessage: 'No interviews scheduled yet.',
              icon: Icons.event_outlined,
            ).animate(delay: 500.ms).fadeIn(),

            const SizedBox(height: 100),
          ],
        ),
      ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatCard({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: PremiumTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PremiumTheme.darkBorder),
          ),
          child: Column(
            children: [
              Icon(icon, color: PremiumTheme.accent, size: 20),
              const SizedBox(height: 8),
              Text(value,
                  style: PremiumTheme.headline3(PremiumTheme.textPrimary)),
              const SizedBox(height: 4),
              Text(label, style: PremiumTheme.bodySmall(PremiumTheme.textSecondary)),
            ],
          ),
        ),
      );
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PremiumTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PremiumTheme.darkBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: PremiumTheme.body(PremiumTheme.textPrimary)
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: PremiumTheme.bodySmall(PremiumTheme.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: PremiumTheme.darkTextTertiary, size: 14),
            ],
          ),
        ),
      );
}

class _EmptySection extends StatelessWidget {
  final String title;
  final String emptyMessage;
  final IconData icon;

  const _EmptySection({
    required this.title,
    required this.emptyMessage,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: PremiumTheme.headline3(PremiumTheme.textPrimary)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: PremiumTheme.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PremiumTheme.darkBorder),
            ),
            child: Column(
              children: [
                Icon(icon, color: PremiumTheme.textMuted, size: 32),
                const SizedBox(height: 8),
                Text(emptyMessage,
                    style: PremiumTheme.body(PremiumTheme.textSecondary)),
              ],
            ),
          ),
        ],
      );
}
