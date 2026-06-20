import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/premium_theme.dart';
import '../providers/generation_provider.dart';
import '../providers/resume_provider.dart';

class GenerateScreen extends ConsumerStatefulWidget {
  final String resumeId;
  const GenerateScreen({super.key, required this.resumeId});

  @override
  ConsumerState<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends ConsumerState<GenerateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jobTitleController = TextEditingController();
  final _companyController = TextEditingController();
  final _jdController = TextEditingController();
  bool _includeCoverLetter = true;

  @override
  void dispose() {
    _jobTitleController.dispose();
    _companyController.dispose();
    _jdController.dispose();
    super.dispose();
  }

  void _generate() {
    if (!_formKey.currentState!.validate()) return;

    ref.read(generationProvider.notifier).generate(
          resumeId: widget.resumeId,
          jobTitle: _jobTitleController.text.trim(),
          companyName: _companyController.text.trim(),
          jobDescription: _jdController.text.trim(),
          generateCoverLetter: _includeCoverLetter,
        );
  }

  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(generationProvider);

    // Watch state to navigate on success
    ref.listen(generationProvider, (prev, next) {
      if (next.hasValue && next.value != null && !next.isLoading) {
        context.pushReplacement(Routes.generationResult);
      }
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: ${next.error}')),
        );
      }
    });

    final isLoading = generationState.isLoading;

    return Scaffold(
      backgroundColor: PremiumTheme.bgPrimary,
      appBar: AppBar(
        title: const Text('Tailor Resume'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Job Details',
                style: PremiumTheme.headline3(PremiumTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Provide the job description. AI will extract keywords and rewrite your bullets.',
                style: PremiumTheme.body(PremiumTheme.textSecondary),
              ),
              const SizedBox(height: 24),

              // Job Title
              TextFormField(
                controller: _jobTitleController,
                decoration: const InputDecoration(
                  labelText: 'Job Title',
                  hintText: 'e.g. Senior Flutter Engineer',
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
                enabled: !isLoading,
              ),
              const SizedBox(height: 16),

              // Company Name
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: 'Company Name',
                  hintText: 'e.g. Acme Corp',
                ),
                enabled: !isLoading,
              ),
              const SizedBox(height: 16),

              // Job Description
              TextFormField(
                controller: _jdController,
                decoration: const InputDecoration(
                  labelText: 'Job Description',
                  hintText: 'Paste the full job description here...',
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
                enabled: !isLoading,
              ),
              const SizedBox(height: 24),

              // Cover Letter Toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: PremiumTheme.accent,
                title: Text('Generate Cover Letter',
                    style: PremiumTheme.body(PremiumTheme.textPrimary)),
                subtitle: Text('Create a tailored cover letter automatically.',
                    style: PremiumTheme.bodySmall(PremiumTheme.textMuted)),
                value: _includeCoverLetter,
                onChanged: isLoading
                    ? null
                    : (val) => setState(() => _includeCoverLetter = val),
              ),
              const SizedBox(height: 32),

              // Submit Button
              ElevatedButton.icon(
                onPressed: isLoading ? null : _generate,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(isLoading ? 'Generating...' : 'Generate Resume'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
