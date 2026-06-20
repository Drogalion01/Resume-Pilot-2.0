import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/premium_theme.dart';
import '../../../core/models/application_model.dart';
import '../providers/application_provider.dart';

class ApplicationListScreen extends ConsumerWidget {
  const ApplicationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(applicationListProvider);

    return Scaffold(
      backgroundColor: PremiumTheme.bgPrimary,
      appBar: AppBar(
        title: const Text('Track Applications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(applicationListProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddApplicationSheet(context, ref),
        backgroundColor: PremiumTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Application',
            style: PremiumTheme.body(Colors.white).copyWith(fontWeight: FontWeight.w600)),
      ),
      body: appsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (apps) {
          if (apps.isEmpty) {
            return _EmptyView(onAdd: () => _showAddApplicationSheet(context, ref));
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(applicationListProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: apps.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _AppCard(app: apps[i])
                  .animate(delay: (i * 50).ms)
                  .fadeIn()
                  .slideY(begin: 0.1),
            ),
          );
        },
      ),
    );
  }

  void _showAddApplicationSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddApplicationSheet(),
    );
  }
}

class _AppCard extends StatelessWidget {
  final Application app;
  const _AppCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(app.status);

    return GestureDetector(
      onTap: () => context.push('${Routes.applications}/${app.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PremiumTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PremiumTheme.darkBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.business_center_rounded, color: statusColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.role,
                    style: PremiumTheme.body(PremiumTheme.textPrimary).copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    app.companyName,
                    style: PremiumTheme.bodySmall(PremiumTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          app.status.displayLabel,
                          style: PremiumTheme.caption(statusColor).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        app.appliedDate != null ? DateFormat('MMM d').format(app.appliedDate!) : '',
                        style: PremiumTheme.caption(PremiumTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: PremiumTheme.textMuted, size: 20),
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

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

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
                  color: PremiumTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.work_off_outlined, color: PremiumTheme.primary, size: 40),
              ).animate().scale(begin: const Offset(0.7, 0.7)).fadeIn(),
              const SizedBox(height: 24),
              Text('No Applications Yet', style: PremiumTheme.headline3(PremiumTheme.textPrimary)).animate(delay: 100.ms).fadeIn(),
              const SizedBox(height: 10),
              Text(
                'Keep track of your job search journey. Add your first application to get started.',
                textAlign: TextAlign.center,
                style: PremiumTheme.body(PremiumTheme.textSecondary),
              ).animate(delay: 200.ms).fadeIn(),
            ],
          ),
        ),
      );
}

class _AddApplicationSheet extends ConsumerStatefulWidget {
  const _AddApplicationSheet();
  @override
  ConsumerState<_AddApplicationSheet> createState() => _AddApplicationSheetState();
}

class _AddApplicationSheetState extends ConsumerState<_AddApplicationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _roleController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _companyController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(applicationRepositoryProvider);
      final newApp = await repo.createApplication(
        companyName: _companyController.text.trim(),
        role: _roleController.text.trim(),
        status: ApplicationStatus.saved.toApiString(),
      );
      ref.read(applicationListProvider.notifier).addApplication(newApp);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: PremiumTheme.bgPrimary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add Application', style: PremiumTheme.headline3(PremiumTheme.textPrimary)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(labelText: 'Company Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _roleController,
                decoration: const InputDecoration(labelText: 'Job Role'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Save Application'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
