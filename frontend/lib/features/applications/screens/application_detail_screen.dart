import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/premium_theme.dart';
import '../../../core/models/application_model.dart';
import '../providers/application_provider.dart';

class ApplicationDetailScreen extends ConsumerWidget {
  final String applicationId;
  const ApplicationDetailScreen({super.key, required this.applicationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(applicationDetailProvider(applicationId));
    final timelineAsync = ref.watch(applicationTimelineProvider(applicationId));

    return Scaffold(
      backgroundColor: PremiumTheme.bgPrimary,
      appBar: AppBar(
        title: const Text('Application Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: PremiumTheme.error),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: PremiumTheme.bgCard,
                  title: Text('Delete Application?', style: PremiumTheme.headline3(PremiumTheme.textPrimary)),
                  content: Text('This action cannot be undone.', style: PremiumTheme.body(PremiumTheme.textSecondary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: PremiumTheme.body(PremiumTheme.error))),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(applicationListProvider.notifier).removeApplication(applicationId);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (app) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: PremiumTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PremiumTheme.darkBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(app.status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          app.status.displayLabel,
                          style: PremiumTheme.caption(_getStatusColor(app.status)).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(app.role, style: PremiumTheme.headline3(PremiumTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(app.companyName, style: PremiumTheme.body(PremiumTheme.textSecondary)),
                  if (app.location != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: PremiumTheme.textMuted, size: 16),
                        const SizedBox(width: 4),
                        Text(app.location!, style: PremiumTheme.bodySmall(PremiumTheme.textMuted)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            Text('Timeline', style: PremiumTheme.headline3(PremiumTheme.textPrimary)),
            const SizedBox(height: 16),

            timelineAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Failed to load timeline', style: PremiumTheme.bodySmall(PremiumTheme.error)),
              data: (events) {
                if (events.isEmpty) {
                  return Text('No events yet.', style: PremiumTheme.body(PremiumTheme.textMuted));
                }
                return Column(
                  children: events.map((e) => _TimelineTile(event: e)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ApplicationStatus status) {
    return switch (status) {
      ApplicationStatus.saved => PremiumTheme.textMuted,
      ApplicationStatus.applied => PremiumTheme.info,
      ApplicationStatus.assessment || ApplicationStatus.hrScreen => PremiumTheme.warning,
      ApplicationStatus.technical || ApplicationStatus.finalRound => PremiumTheme.accent,
      ApplicationStatus.offer => PremiumTheme.success,
      ApplicationStatus.rejected || ApplicationStatus.withdrawn => PremiumTheme.error,
    };
  }
}

class _TimelineTile extends StatelessWidget {
  final TimelineEvent event;
  const _TimelineTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: PremiumTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 40,
                color: PremiumTheme.darkBorder,
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.description,
                  style: PremiumTheme.body(PremiumTheme.textPrimary).copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, yyyy • h:mm a').format(event.createdAt),
                  style: PremiumTheme.caption(PremiumTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
