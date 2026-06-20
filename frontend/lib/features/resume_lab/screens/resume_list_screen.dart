// lib/features/resume_lab/screens/resume_list_screen.dart
//
// Resume Lab — main list screen showing all uploaded resumes.
// Floating action button → upload. Tap card → resume detail.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/premium_theme.dart';
import '../../../core/models/resume_model.dart';
import '../providers/resume_provider.dart';

class ResumeListScreen extends ConsumerWidget {
  const ResumeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumesAsync = ref.watch(resumeListProvider);

    return Scaffold(
      backgroundColor: PremiumTheme.bgPrimary,
      appBar: AppBar(
        title: const Text('Resume Lab'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.read(resumeListProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.upload),
        backgroundColor: PremiumTheme.primary,
        icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
        label: Text('Upload Resume',
            style: PremiumTheme.body(Colors.white)
                .copyWith(fontWeight: FontWeight.w600)),
      ),
      body: resumesAsync.when(
        loading: () => _buildSkeletons(),
        error: (e, _) => _ErrorView(onRetry: () => ref.read(resumeListProvider.notifier).refresh()),
        data: (resumes) => resumes.isEmpty
            ? _EmptyView(onUpload: () => context.push(Routes.upload))
            : _ResumeListView(resumes: resumes),
      ),
    );
  }

  Widget _buildSkeletons() => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => _SkeletonCard(),
      );
}

// ── List View ──────────────────────────────────────────────────────────────────

class _ResumeListView extends ConsumerWidget {
  final List<Resume> resumes;
  const _ResumeListView({required this.resumes});

  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshIndicator(
        color: PremiumTheme.accent,
        onRefresh: () => ref.read(resumeListProvider.notifier).refresh(),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: resumes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _ResumeCard(resume: resumes[i])
              .animate(delay: (i * 60).ms)
              .fadeIn()
              .slideY(begin: 0.1),
        ),
      );
}

// ── Resume Card ────────────────────────────────────────────────────────────────

class _ResumeCard extends ConsumerWidget {
  final Resume resume;
  const _ResumeCard({required this.resume});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Dismissible(
        key: ValueKey(resume.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: PremiumTheme.error.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: PremiumTheme.error),
        ),
        confirmDismiss: (_) async => _confirmDelete(context),
        onDismissed: (_) => ref.read(resumeListProvider.notifier).removeResume(resume.id),
        child: GestureDetector(
          onTap: () => context.push('${Routes.resumeLab}/${resume.id}'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PremiumTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: resume.isMaster
                    ? PremiumTheme.accent.withOpacity(0.4)
                    : PremiumTheme.darkBorder,
              ),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: resume.isMaster
                        ? PremiumTheme.accent.withOpacity(0.12)
                        : PremiumTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    resume.isMaster
                        ? Icons.star_rounded
                        : Icons.description_outlined,
                    color: resume.isMaster
                        ? PremiumTheme.accent
                        : PremiumTheme.textSecondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              resume.title,
                              style: PremiumTheme.body(PremiumTheme.textPrimary)
                                  .copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (resume.isMaster)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: PremiumTheme.accent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Master',
                                  style: PremiumTheme.caption(PremiumTheme.accent)
                                      .copyWith(fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        resume.originalFilename ?? 'Uploaded resume',
                        style: PremiumTheme.bodySmall(PremiumTheme.textMuted),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Added ${DateFormat('MMM d, yyyy').format(resume.createdAt)}',
                        style: PremiumTheme.caption(PremiumTheme.textMuted),
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.chevron_right_rounded,
                    color: PremiumTheme.textMuted, size: 20),
              ],
            ),
          ),
        ),
      );

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: PremiumTheme.bgCard,
          title: Text('Delete resume?',
              style: PremiumTheme.headline3(PremiumTheme.textPrimary)),
          content: Text(
            'This will permanently delete "${resume.title}" and all its versions.',
            style: PremiumTheme.body(PremiumTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: PremiumTheme.body(PremiumTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete',
                  style: PremiumTheme.body(PremiumTheme.error)),
            ),
          ],
        ),
      );
}

// ── Empty State ────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onUpload;
  const _EmptyView({required this.onUpload});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: PremiumTheme.accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.upload_file_rounded,
                    color: PremiumTheme.accent, size: 40),
              ).animate().scale(begin: const Offset(0.7, 0.7)).fadeIn(),
              const SizedBox(height: 24),
              Text('No resumes yet',
                      style: PremiumTheme.headline3(PremiumTheme.textPrimary))
                  .animate(delay: 100.ms).fadeIn(),
              const SizedBox(height: 10),
              Text(
                'Upload your master resume to get started. AI will use it to generate tailored versions for each application.',
                textAlign: TextAlign.center,
                style: PremiumTheme.body(PremiumTheme.textSecondary),
              ).animate(delay: 200.ms).fadeIn(),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.upload_rounded),
                label: const Text('Upload Resume'),
              ).animate(delay: 300.ms).fadeIn(),
            ],
          ),
        ),
      );
}

// ── Error View ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: PremiumTheme.error, size: 48),
            const SizedBox(height: 16),
            Text('Failed to load resumes',
                style: PremiumTheme.body(PremiumTheme.textPrimary)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

// ── Skeleton Card ──────────────────────────────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 80,
        decoration: BoxDecoration(
          color: PremiumTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
            color: PremiumTheme.bgSecondary,
            duration: 1200.ms,
          );
}
