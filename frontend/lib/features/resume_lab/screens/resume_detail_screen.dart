import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/premium_theme.dart';
import '../providers/resume_provider.dart';
import '../../../core/models/resume_model.dart';

class ResumeDetailScreen extends ConsumerWidget {
  final String resumeId;
  const ResumeDetailScreen({super.key, required this.resumeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumeAsync = ref.watch(resumeDetailProvider(resumeId));
    final versionsAsync = ref.watch(resumeVersionsProvider(resumeId));

    return Scaffold(
      backgroundColor: PremiumTheme.bgPrimary,
      appBar: AppBar(
        title: const Text('Resume Details'),
        actions: [
          resumeAsync.maybeWhen(
            data: (resume) => IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Download Original',
              onPressed: () async {
                try {
                  final url = await ref.read(resumeRepositoryProvider).getDownloadUrl(resume.id);
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to download: $e'), backgroundColor: PremiumTheme.error),
                    );
                  }
                }
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: resumeAsync.maybeWhen(
        data: (resume) => FloatingActionButton.extended(
          onPressed: () => context.push(Routes.generate, extra: resume.id),
          backgroundColor: PremiumTheme.accent,
          icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
          label: Text('Tailor Resume',
              style: PremiumTheme.body(Colors.white)
                  .copyWith(fontWeight: FontWeight.w600)),
        ),
        orElse: () => null,
      ),
      body: resumeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (resume) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(resumeDetailProvider(resumeId));
            ref.invalidate(resumeVersionsProvider(resumeId));
          },
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Resume Header
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
                        const Icon(Icons.description_outlined, color: PremiumTheme.accent, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            resume.title,
                            style: PremiumTheme.headline3(PremiumTheme.textPrimary),
                          ),
                        ),
                        if (resume.isMaster)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: PremiumTheme.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Master',
                                style: PremiumTheme.caption(PremiumTheme.accent)
                                    .copyWith(fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Filename: ${resume.originalFilename ?? "N/A"}',
                        style: PremiumTheme.bodySmall(PremiumTheme.textSecondary)),
                    Text('Added: ${DateFormat('MMM d, yyyy').format(resume.createdAt)}',
                        style: PremiumTheme.bodySmall(PremiumTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Versions section
              Text('Tailored Versions', style: PremiumTheme.headline3(PremiumTheme.textPrimary)),
              const SizedBox(height: 16),
              
              versionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading versions: $e', style: PremiumTheme.bodySmall(PremiumTheme.error)),
                data: (versions) {
                  if (versions.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: PremiumTheme.bgCard,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text('No tailored versions yet. Tap "Tailor Resume" to generate one with AI.',
                          style: PremiumTheme.body(PremiumTheme.textMuted),
                          textAlign: TextAlign.center),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: versions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _VersionCard(version: versions[i]),
                  );
                },
              ),
              const SizedBox(height: 80), // spacing for FAB
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  final ResumeVersion version;
  const _VersionCard({required this.version});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.work_outline_rounded, color: PremiumTheme.textSecondary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  version.title,
                  style: PremiumTheme.body(PremiumTheme.textPrimary).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (version.jobTitle != null || version.companyName != null) ...[
            const SizedBox(height: 8),
            Text(
              '${version.jobTitle ?? "Role"} at ${version.companyName ?? "Company"}',
              style: PremiumTheme.bodySmall(PremiumTheme.textSecondary),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Created ${DateFormat('MMM d, yyyy').format(version.createdAt)} • Generated via ${version.generationMode == "tailored" ? "AI" : "Manual"}',
            style: PremiumTheme.caption(PremiumTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
