import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/premium_theme.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../shared/widgets/primary_button.dart';
import '../providers/interview_provider.dart';

// ── Interview phases ordered in pipeline sequence ──────────────────────────
const _phases = [
  {'value': 'phone_screen',      'label': 'Phone Screen',        'icon': Icons.phone_outlined},
  {'value': 'technical',         'label': 'Technical Round',     'icon': Icons.code_rounded},
  {'value': 'take_home_review',  'label': 'Take-Home / Review',  'icon': Icons.assignment_outlined},
  {'value': 'behavioral',        'label': 'Behavioural Round',   'icon': Icons.psychology_outlined},
  {'value': 'onsite',            'label': 'On-site Panel',       'icon': Icons.business_center_outlined},
  {'value': 'final_round',       'label': 'Final Round / Offer', 'icon': Icons.emoji_events_outlined},
];

class ScheduleInterviewScreen extends ConsumerStatefulWidget {
  final String applicationId;

  const ScheduleInterviewScreen({super.key, required this.applicationId});

  @override
  ConsumerState<ScheduleInterviewScreen> createState() => _ScheduleInterviewScreenState();
}

class _ScheduleInterviewScreenState extends ConsumerState<ScheduleInterviewScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Phase selection
  String _interviewType = 'phone_screen';

  // Date / time
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));

  // Form fields
  int _durationMinutes = 60;
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _reviewNotesController = TextEditingController();

  // Reminders
  bool _reminder1h = true;
  bool _reminder24h = false;
  bool _reminder15min = false;

  bool _isLoading = false;

  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    _reviewNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
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

    if (date == null || !mounted) return;

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

    if (time == null || !mounted) return;

    setState(() {
      _scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Combine prep notes and review notes into the notes field as structured text
      final combinedNotes = [
        if (_notesController.text.trim().isNotEmpty)
          '📝 Prep Notes:\n${_notesController.text.trim()}',
        if (_reviewNotesController.text.trim().isNotEmpty)
          '🔍 Review Notes:\n${_reviewNotesController.text.trim()}',
      ].join('\n\n');

      final interview = InterviewData(
        id: '',
        applicationId: widget.applicationId,
        interviewType: _interviewType,
        scheduledAt: _scheduledAt,
        durationMinutes: _durationMinutes,
        locationOrLink: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        notes: combinedNotes.isEmpty ? null : combinedNotes,
        reminderEnabled: _reminder1h || _reminder24h || _reminder15min,
      );

      final saved = await ref
          .read(applicationInterviewsProvider(widget.applicationId).notifier)
          .schedule(interview);

      // Schedule local notifications for selected reminders
      final notifSvc = NotificationService();
      final phaseLabel = _phases
          .firstWhere((p) => p['value'] == _interviewType,
              orElse: () => {'label': _interviewType})['label'] as String;

      if (_reminder24h) {
        final t = saved.scheduledAt.subtract(const Duration(hours: 24));
        if (t.isAfter(DateTime.now())) {
          await notifSvc.scheduleInterviewReminder(
            id: '${saved.id}_24h'.hashCode,
            title: 'Interview Tomorrow — $phaseLabel',
            body: 'Your $phaseLabel interview is in 24 hours. Review your prep notes!',
            scheduledDate: t,
          );
        }
      }

      if (_reminder1h) {
        final t = saved.scheduledAt.subtract(const Duration(hours: 1));
        if (t.isAfter(DateTime.now())) {
          await notifSvc.scheduleInterviewReminder(
            id: '${saved.id}_1h'.hashCode,
            title: 'Interview in 1 Hour — $phaseLabel',
            body: 'Your $phaseLabel interview starts in 1 hour. Good luck! 🍀',
            scheduledDate: t,
          );
        }
      }

      if (_reminder15min) {
        final t = saved.scheduledAt.subtract(const Duration(minutes: 15));
        if (t.isAfter(DateTime.now())) {
          await notifSvc.scheduleInterviewReminder(
            id: '${saved.id}_15m'.hashCode,
            title: 'Starting Soon — $phaseLabel',
            body: 'Your $phaseLabel interview starts in 15 minutes!',
            scheduledDate: t,
          );
        }
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$phaseLabel interview scheduled!'),
            backgroundColor: PremiumTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: PremiumTheme.error,
          ),
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
      appBar: AppBar(title: const Text('Schedule Interview Phase')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Phase selector ──────────────────────────────────────────
              _SectionLabel('Interview Phase'),
              const SizedBox(height: 12),
              _PhasePicker(
                selected: _interviewType,
                onSelected: (v) => setState(() => _interviewType = v),
              ),
              const SizedBox(height: 24),

              // ── Date & Time ─────────────────────────────────────────────
              _SectionLabel('Date & Time'),
              const SizedBox(height: 12),
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
                      const Icon(Icons.calendar_month_rounded,
                          color: PremiumTheme.accent),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Scheduled At',
                              style: PremiumTheme.label(PremiumTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEE, MMM d, yyyy • h:mm a')
                                .format(_scheduledAt),
                            style:
                                PremiumTheme.body(PremiumTheme.textPrimary),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.edit_outlined,
                          color: PremiumTheme.textSecondary, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Location ────────────────────────────────────────────────
              _SectionLabel('Location / Meeting Link'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                style: PremiumTheme.body(PremiumTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'e.g. https://meet.google.com/abc or 123 Office Blvd',
                  prefixIcon: Icon(Icons.videocam_outlined),
                ),
              ),
              const SizedBox(height: 20),

              // ── Duration ────────────────────────────────────────────────
              _SectionLabel('Duration (minutes)'),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _durationMinutes.toString(),
                keyboardType: TextInputType.number,
                style: PremiumTheme.body(PremiumTheme.textPrimary),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                onChanged: (v) => _durationMinutes = int.tryParse(v) ?? 60,
              ),
              const SizedBox(height: 24),

              // ── Prep Notes ──────────────────────────────────────────────
              _SectionLabel('Prep Notes'),
              const SizedBox(height: 8),
              Text(
                'What to prepare, research, or bring for this round',
                style: PremiumTheme.bodySmall(PremiumTheme.textMuted),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                style: PremiumTheme.body(PremiumTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText:
                      'e.g. Review system design, practice STAR method...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),

              // ── Review Notes (post-interview) ───────────────────────────
              _SectionLabel('Review Notes (post-interview)'),
              const SizedBox(height: 8),
              Text(
                'Fill in after the interview — how it went, feedback received',
                style: PremiumTheme.bodySmall(PremiumTheme.textMuted),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reviewNotesController,
                maxLines: 4,
                style: PremiumTheme.body(PremiumTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'e.g. Went well. Struggled with dynamic programming question...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),

              // ── Reminders ───────────────────────────────────────────────
              _SectionLabel('Reminders'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: PremiumTheme.darkCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PremiumTheme.darkBorder),
                ),
                child: Column(
                  children: [
                    _ReminderTile(
                      title: '24 hours before',
                      icon: Icons.notifications_outlined,
                      value: _reminder24h,
                      onChanged: (v) => setState(() => _reminder24h = v),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _ReminderTile(
                      title: '1 hour before',
                      icon: Icons.alarm_rounded,
                      value: _reminder1h,
                      onChanged: (v) => setState(() => _reminder1h = v),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _ReminderTile(
                      title: '15 minutes before',
                      icon: Icons.access_time_rounded,
                      value: _reminder15min,
                      onChanged: (v) => setState(() => _reminder15min = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              PrimaryButton(
                label: 'Schedule Interview Phase',
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

// ── Phase picker widget ────────────────────────────────────────────────────────

class _PhasePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _PhasePicker({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _phases.map((phase) {
        final value = phase['value'] as String;
        final label = phase['label'] as String;
        final icon = phase['icon'] as IconData;
        final isSelected = selected == value;

        return GestureDetector(
          onTap: () => onSelected(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? PremiumTheme.primary.withOpacity(0.15)
                  : PremiumTheme.darkCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? PremiumTheme.accent
                    : PremiumTheme.darkBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 16,
                    color: isSelected
                        ? PremiumTheme.accent
                        : PremiumTheme.textSecondary),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: PremiumTheme.bodySmall(
                    isSelected
                        ? PremiumTheme.accent
                        : PremiumTheme.textSecondary,
                  ).copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: PremiumTheme.label(PremiumTheme.textSecondary)
            .copyWith(letterSpacing: 0.8),
      );
}

class _ReminderTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ReminderTile({
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        secondary: Icon(icon, color: PremiumTheme.accent, size: 20),
        title: Text(title,
            style: PremiumTheme.body(PremiumTheme.textPrimary)),
        value: value,
        onChanged: onChanged,
        activeColor: PremiumTheme.accent,
      );
}
