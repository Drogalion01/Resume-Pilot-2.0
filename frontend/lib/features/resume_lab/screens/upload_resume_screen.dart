// lib/features/resume_lab/screens/upload_resume_screen.dart
//
// File picker → title input → upload with progress → success → back to list.
// Accepts PDF and DOCX only (validated server-side too).

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/premium_theme.dart';
import '../../../core/models/resume_model.dart';
import '../../../shared/widgets/primary_button.dart';
import '../providers/resume_provider.dart';

class UploadResumeScreen extends ConsumerStatefulWidget {
  const UploadResumeScreen({super.key});

  @override
  ConsumerState<UploadResumeScreen> createState() => _UploadResumeScreenState();
}

class _UploadResumeScreenState extends ConsumerState<UploadResumeScreen> {
  final _titleCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  PlatformFile? _pickedFile;
  bool _isMaster = false;
  bool _isUploading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    // 10 MB limit
    if ((file.size) > 10 * 1024 * 1024) {
      setState(() => _error = 'File must be under 10 MB');
      return;
    }

    setState(() {
      _pickedFile = file;
      _error = null;
      if (_titleCtrl.text.isEmpty) {
        // Auto-fill title from filename (without extension)
        _titleCtrl.text = file.name
            .replaceAll(RegExp(r'\.(pdf|docx)$', caseSensitive: false), '')
            .replaceAll('_', ' ')
            .replaceAll('-', ' ');
      }
    });
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFile == null) {
      setState(() => _error = 'Please select a file first');
      return;
    }
    if (_pickedFile!.path == null) {
      setState(() => _error = 'File path unavailable — try picking again');
      return;
    }

    setState(() { _isUploading = true; _error = null; });

    try {
      final resume = await ref.read(resumeRepositoryProvider).uploadResume(
            filePath: _pickedFile!.path!,
            title: _titleCtrl.text.trim(),
            isMaster: _isMaster,
          );
      await ref.read(resumeListProvider.notifier).addResume(resume);
      if (mounted) context.pop();
    } catch (e) {
      setState(() {
        _isUploading = false;
        _error = 'Upload failed. Please check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.bgPrimary,
      appBar: AppBar(
        title: const Text('Upload Resume'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── File picker zone ─────────────────────────────────────
                GestureDetector(
                  onTap: _isUploading ? null : _pickFile,
                  child: AnimatedContainer(
                    duration: 300.ms,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    decoration: BoxDecoration(
                      color: _pickedFile != null
                          ? PremiumTheme.accent.withOpacity(0.08)
                          : PremiumTheme.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _pickedFile != null
                            ? PremiumTheme.accent.withOpacity(0.5)
                            : PremiumTheme.darkBorder,
                        width: 1.5,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _pickedFile != null
                              ? Icons.check_circle_rounded
                              : Icons.upload_file_rounded,
                          color: _pickedFile != null
                              ? PremiumTheme.success
                              : PremiumTheme.accent,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _pickedFile != null
                              ? _pickedFile!.name
                              : 'Tap to select PDF or DOCX',
                          style: PremiumTheme.body(
                            _pickedFile != null
                                ? PremiumTheme.textPrimary
                                : PremiumTheme.textSecondary,
                          ).copyWith(fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                        if (_pickedFile != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${(_pickedFile!.size / 1024).toStringAsFixed(0)} KB',
                            style: PremiumTheme.caption(PremiumTheme.textMuted),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _pickFile,
                            child: Text('Change file',
                                style: PremiumTheme.bodySmall(PremiumTheme.accent)),
                          ),
                        ] else ...[
                          const SizedBox(height: 6),
                          Text('Max 10 MB',
                              style: PremiumTheme.caption(PremiumTheme.textMuted)),
                        ],
                      ],
                    ),
                  ),
                ).animate().fadeIn().slideY(begin: 0.1),

                const SizedBox(height: 24),

                // ── Error ─────────────────────────────────────────────────
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: PremiumTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PremiumTheme.error.withOpacity(0.4)),
                    ),
                    child: Text(_error!,
                        style: PremiumTheme.bodySmall(PremiumTheme.error)),
                  ).animate().fadeIn().shakeX(hz: 3),
                  const SizedBox(height: 16),
                ],

                // ── Title field ───────────────────────────────────────────
                Text('Resume title',
                    style: PremiumTheme.label(PremiumTheme.textSecondary)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleCtrl,
                  style: PremiumTheme.body(PremiumTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Software Engineer — Google Application',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Title is required';
                    if (v.trim().length < 3) return 'Title too short';
                    return null;
                  },
                ).animate(delay: 100.ms).fadeIn(),

                const SizedBox(height: 20),

                // ── Master toggle ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: PremiumTheme.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isMaster
                          ? PremiumTheme.accent.withOpacity(0.4)
                          : PremiumTheme.darkBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: PremiumTheme.accent, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Set as master resume',
                                style: PremiumTheme.body(PremiumTheme.textPrimary)
                                    .copyWith(fontWeight: FontWeight.w600)),
                            Text(
                              'AI will use this as the base to generate tailored versions',
                              style: PremiumTheme.caption(PremiumTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isMaster,
                        onChanged: (v) => setState(() => _isMaster = v),
                        activeColor: PremiumTheme.accent,
                      ),
                    ],
                  ),
                ).animate(delay: 150.ms).fadeIn(),

                const SizedBox(height: 32),

                // ── Upload button ─────────────────────────────────────────
                PrimaryButton(
                  label: 'Upload Resume',
                  onTap: _isUploading ? null : _upload,
                  isLoading: _isUploading,
                ).animate(delay: 200.ms).fadeIn(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
