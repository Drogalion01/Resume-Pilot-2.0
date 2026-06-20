import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/premium_theme.dart';
import '../providers/generation_provider.dart';

class GenerationResultScreen extends ConsumerWidget {
  const GenerationResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generationValue = ref.watch(generationProvider).valueOrNull;

    if (generationValue == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Result')),
        body: const Center(child: Text('No result found.')),
      );
    }

    final result = generationValue;
    final atsScore = result.atsScore;
    final recruiterScore = result.recruiterScore;

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
            // Score Cards
            Row(
              children: [
                Expanded(
                  child: _ScoreCard(
                    title: 'ATS Score',
                    score: atsScore,
                    icon: Icons.computer_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ScoreCard(
                    title: 'Recruiter Score',
                    score: recruiterScore,
                    icon: Icons.person_search_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Keywords
            Text('Keywords Matched', style: PremiumTheme.headline3(PremiumTheme.textPrimary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.matchedKeywords
                  .map((k) => Chip(
                        label: Text(k),
                        backgroundColor: PremiumTheme.accent.withOpacity(0.1),
                        labelStyle: PremiumTheme.bodySmall(PremiumTheme.accent),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),

            if (result.missingKeywords.isNotEmpty) ...[
              Text('Keywords Missing', style: PremiumTheme.headline3(PremiumTheme.textPrimary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: result.missingKeywords
                    .map((k) => Chip(
                          label: Text(k),
                          backgroundColor: PremiumTheme.error.withOpacity(0.1),
                          labelStyle: PremiumTheme.bodySmall(PremiumTheme.error),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 32),
            ],

            // Cover Letter
            if (result.coverLetter != null) ...[
              Text('Cover Letter', style: PremiumTheme.headline3(PremiumTheme.textPrimary)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PremiumTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PremiumTheme.darkBorder),
                ),
                child: SelectableText(
                  result.coverLetter!,
                  style: PremiumTheme.body(PremiumTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Next steps
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(generationProvider.notifier).reset();
                  context.go('${Routes.resumeLab}/${result.resumeVersionId}');
                },
                icon: const Icon(Icons.description_rounded),
                label: const Text('View Tailored Resume'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PremiumTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PremiumTheme.darkBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            score.toString(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 32,
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
        ],
      ),
    );
  }
}
