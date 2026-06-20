import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/premium_theme.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../shared/widgets/primary_button.dart';
import '../providers/interview_provider.dart';

class ScheduleInterviewScreen extends ConsumerStatefulWidget {
  final String applicationId;

  const ScheduleInterviewScreen({super.key, required this.applicationId});

  @override
  ConsumerState<ScheduleInterviewScreen> createState() => _ScheduleInterviewScreenState();
}

class _ScheduleInterviewScreenState extends ConsumerState<ScheduleInterviewScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String _interviewType = 'technical';
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  int _durationMinutes = 60;
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  bool _reminderEnabled = true;

  bool _isLoading = false;

  final _types = [
    'phone_screen',
    'technical',
    'behavioral',
    'take_home_review',
    'onsite',
    'final_round'
  ];

  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: PremiumTheme.primary,
            onPrimary: Colors.white,
            surface: PremiumTheme.darkSurface,
            onSurface: PremiumTheme.darkTextPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: PremiumTheme.primary,
            onPrimary: Colors.white,
            surface: PremiumTheme.darkSurface,
            onSurface: PremiumTheme.darkTextPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (time == null) return;

    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final interview = InterviewData(
        id: '',
        applicationId: widget.applicationId,
        interviewType: _interviewType,
        scheduledAt: _scheduledAt,
        durationMinutes: _durationMinutes,
        locationOrLink: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        reminderEnabled: _reminderEnabled,
      );

      final saved = await ref.read(applicationInterviewsProvider(widget.applicationId).notifier).schedule(interview);

      // Schedule local notification if enabled
      if (_reminderEnabled) {
        final reminderTime = saved.scheduledAt.subtract(const Duration(hours: 1));
        if (reminderTime.isAfter(DateTime.now())) {
          await NotificationService().scheduleInterviewReminder(
            id: saved.id.hashCode,
            title: 'Upcoming Interview',
            body: "Your ${_interviewType.replaceAll('_', ' ')} interview starts in 1 hour!",
            scheduledDate: reminderTime,
          );
        }
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Interview scheduled!'), backgroundColor: PremiumTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: \$e'), backgroundColor: PremiumTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.bgPrimary,
      appBar: AppBar(
        title: const Text('Schedule Interview'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Interview Details', style: PremiumTheme.headline3(PremiumTheme.textPrimary)),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _interviewType,
                dropdownColor: PremiumTheme.darkSurface,
                decoration: const InputDecoration(labelText: 'Interview Type'),
                items: _types.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.replaceAll('_', ' ').toUpperCase(), style: PremiumTheme.body(PremiumTheme.textPrimary)),
                )).toList(),
                onChanged: (v) => setState(() => _interviewType = v!),
              ),
              const SizedBox(height: 20),

              GestureDetector(
                onTap: _pickDateTime,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PremiumTheme.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PremiumTheme.darkBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: PremiumTheme.accent),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Date & Time', style: PremiumTheme.label(PremiumTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEE, MMM d, yyyy • h:mm a').format(_scheduledAt),
                            style: PremiumTheme.body(PremiumTheme.textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _locationController,
                style: PremiumTheme.body(PremiumTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Location or Meeting Link (e.g. Zoom)',
                  prefixIcon: Icon(Icons.videocam_outlined),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                initialValue: _durationMinutes.toString(),
                keyboardType: TextInputType.number,
                style: PremiumTheme.body(PremiumTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Duration (minutes)',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                onChanged: (v) => _durationMinutes = int.tryParse(v) ?? 60,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _notesController,
                maxLines: 3,
                style: PremiumTheme.body(PremiumTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),

              SwitchListTile(
                title: Text('Enable Reminders', style: PremiumTheme.body(PremiumTheme.textPrimary)),
                subtitle: Text('Get notified 1 hour before', style: PremiumTheme.bodySmall(PremiumTheme.textSecondary)),
                value: _reminderEnabled,
                onChanged: (v) => setState(() => _reminderEnabled = v),
                activeColor: PremiumTheme.accent,
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 40),

              PrimaryButton(
                label: 'Schedule Interview',
                isLoading: _isLoading,
                onTap: _save,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
