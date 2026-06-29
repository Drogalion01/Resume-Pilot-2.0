import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/premium_theme.dart';
import '../../../core/models/generation_model.dart';
import '../providers/generation_provider.dart';

class GenerationResultScreen extends ConsumerWidget {
  const GenerationResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generationValue = ref.watch(generationProvider).valueOrNull;
    final downloadState = ref.watch(pdfDownloadProvider);

    if (generationValue == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Result')),
        body: const Center(child: Text('No result found.')),
      );
    }

    final result = generationValue;
    final isDownloading = downloadState.status == DownloadStatus.loading;

    // Show snack when download completes or errors
    ref.listen(pdfDownloadProvider, (prev, next) {
      if (next.status == DownloadStatus.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF downloaded successfully ✓'),
            backgroundColor: PremiumTheme.success,
          ),
        );
        ref.read(pdfDownloadProvider.notifier).reset();
      } else if (next.status == DownloadStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'PDF download failed. Please try again.'),
            backgroundColor: PremiumTheme.error,
          ),
        );
        ref.read(pdfDownloadProvider.notifier).reset();
      }
    });

    return Scaffold(
      backgroundColor: PremiumTheme.bgPrimary,
      appBar: AppBar(
        title: const Text('Tailored Resume'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            ref.read(generationProvider.notifier).reset();
            context.go(Routes.resumeLab);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Score Cards ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _ScoreCard(
                    title: 'ATS Score',
                    score: result.atsScore,
                    icon: Icons.computer_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ScoreCard(
                    title: 'Recruiter Score',
                    score: result.recruiterScore,
                    icon: Icons.person_search_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Download buttons ─────────────────────────────────────────
            _DownloadSection(
              result: result,
              isDownloading: isDownloading,
              onDownloadResume: () {
                ref.read(pdfDownloadProvider.notifier).downloadResume(
                  result.resumeVersionId.toString(),
                  'tailored_resume.pdf',
                );
              },
              onDownloadCoverLetter: result.coverLetterId != null
                  ? () {
                      ref.read(pdfDownloadProvider.notifier).downloadCoverLetter(
                        result.coverLetterId!.toString(),
                        'cover_letter.pdf',
                      );
                    }
                  : null,
            ),
            const SizedBox(height: 24),

            // ── Keywords ─────────────────────────────────────────────────
            if (result.matchedKeywords.isNotEmpty) ...[
              Text('Keywords Matched',
                  style: PremiumTheme.headline3(PremiumTheme.textPrimary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: result.matchedKeywords
                    .map((k) => Chip(
                          label: Text(k),
                          backgroundColor:
                              PremiumTheme.success.withOpacity(0.1),
                          labelStyle:
                              PremiumTheme.bodySmall(PremiumTheme.success),
                          side: BorderSide(
                              color: PremiumTheme.success.withOpacity(0.3)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            if (result.missingKeywords.isNotEmpty) ...[
              Text('Keywords to Add',
                  style: PremiumTheme.headline3(PremiumTheme.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'Consider adding these keywords to further boost your score',
                style: PremiumTheme.bodySmall(PremiumTheme.textMuted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: result.missingKeywords
                    .map((k) => Chip(
                          label: Text(k),
                          backgroundColor:
                              PremiumTheme.warning.withOpacity(0.1),
                          labelStyle:
                              PremiumTheme.bodySmall(PremiumTheme.warning),
                          side: BorderSide(
                              color: PremiumTheme.warning.withOpacity(0.3)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],

            // ── Cover Letter preview ──────────────────────────────────────
            if (result.coverLetter != null) ...[
              Row(
                children: [
                  Text('Cover Letter',
                      style: PremiumTheme.headline3(PremiumTheme.textPrimary)),
                  const Spacer(),
                  // Copy button
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: result.coverLetter!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Cover letter copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded,
                        color: PremiumTheme.accent, size: 18),
                    tooltip: 'Copy to clipboard',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: PremiumTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PremiumTheme.darkBorder),
                ),
                child: SelectableText(
                  result.coverLetter!,
                  style: PremiumTheme.body(PremiumTheme.textSecondary)
                      .copyWith(height: 1.6),
                ),
              ),
              const SizedBox(height: 32),
            ],

            // ── CTA ───────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(generationProvider.notifier).reset();
                  context.go('${Routes.resumeLab}/${result.resumeVersionId}');
                },
                icon: const Icon(Icons.description_rounded),
                label: const Text('View Full Tailored Resume'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Download section widget ────────────────────────────────────────────────────

class _DownloadSection extends StatelessWidget {
  final GenerationResult result;
  final bool isDownloading;
  final VoidCallback onDownloadResume;
  final VoidCallback? onDownloadCoverLetter;

  const _DownloadSection({
    required this.result,
    required this.isDownloading,
    required this.onDownloadResume,
    this.onDownloadCoverLetter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            PremiumTheme.primary.withOpacity(0.08),
            PremiumTheme.primaryDark.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PremiumTheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.download_rounded,
                  color: PremiumTheme.accent, size: 18),
              const SizedBox(width: 8),
              Text('Download PDFs',
                  style: PremiumTheme.body(PremiumTheme.textPrimary)
                      .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DownloadButton(
                  label: 'Resume PDF',
                  icon: Icons.description_outlined,
                  isLoading: isDownloading,
                  onTap: onDownloadResume,
                  color: PremiumTheme.primary,
                ),
              ),
              if (onDownloadCoverLetter != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _DownloadButton(
                    label: 'Cover Letter',
                    icon: Icons.mail_outline_rounded,
                    isLoading: isDownloading,
                    onTap: onDownloadCoverLetter!,
                    color: PremiumTheme.accentPink,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onTap;
  final Color color;

  const _DownloadButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.15),
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.4)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: isLoading
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: color,
              ),
            )
          : Icon(icon, size: 16),
      label: Text(label,
          style: PremiumTheme.bodySmall(color)
              .copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

// ── Score card ─────────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final String title;
  final int score;
  final IconData icon;

  const _ScoreCard({required this.title, required this.score, required this.icon});

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? PremiumTheme.success
        : score >= 60
            ? PremiumTheme.warning
            : PremiumTheme.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PremiumTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            '$score',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: PremiumTheme.caption(PremiumTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // Score bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
