// lib/core/models/application_model.dart
//
// Application, Interview, Reminder, TimelineEvent — matches backend schemas.

// ── Application statuses ───────────────────────────────────────────────────────

enum ApplicationStatus {
  saved,
  applied,
  assessment,
  hrScreen,
  technical,
  finalRound,
  offer,
  rejected,
  withdrawn;

  static ApplicationStatus fromString(String s) => switch (s) {
        'saved'       => saved,
        'applied'     => applied,
        'assessment'  => assessment,
        'hr_screen'   => hrScreen,
        'technical'   => technical,
        'final_round' => finalRound,
        'offer'       => offer,
        'rejected'    => rejected,
        'withdrawn'   => withdrawn,
        _             => saved,
      };

  String toApiString() => switch (this) {
        saved       => 'saved',
        applied     => 'applied',
        assessment  => 'assessment',
        hrScreen    => 'hr_screen',
        technical   => 'technical',
        finalRound  => 'final_round',
        offer       => 'offer',
        rejected    => 'rejected',
        withdrawn   => 'withdrawn',
      };

  String get displayLabel => switch (this) {
        saved       => 'Saved',
        applied     => 'Applied',
        assessment  => 'Assessment',
        hrScreen    => 'HR Screen',
        technical   => 'Technical',
        finalRound  => 'Final Round',
        offer       => 'Offer',
        rejected    => 'Rejected',
        withdrawn   => 'Withdrawn',
      };
}

// ── Application ────────────────────────────────────────────────────────────────

class Application {
  final String id;
  final String userId;
  final String companyName;
  final String role;
  final ApplicationStatus status;
  final String? location;
  final String? sourceUrl;
  final String? recruiterName;
  final DateTime? appliedDate;
  final String? resumeVersionId;
  final String? coverLetterId;
  final String? notesText;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Application({
    required this.id,
    required this.userId,
    required this.companyName,
    required this.role,
    required this.status,
    this.location,
    this.sourceUrl,
    this.recruiterName,
    this.appliedDate,
    this.resumeVersionId,
    this.coverLetterId,
    this.notesText,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Application.fromJson(Map<String, dynamic> j) => Application(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        companyName: j['company_name'] as String,
        role: j['role'] as String,
        status: ApplicationStatus.fromString(j['status'] as String? ?? 'saved'),
        location: j['location'] as String?,
        sourceUrl: j['source_url'] as String?,
        recruiterName: j['recruiter_name'] as String?,
        appliedDate: j['applied_date'] != null
            ? DateTime.parse(j['applied_date'] as String)
            : null,
        resumeVersionId: j['resume_version_id'] as String?,
        coverLetterId: j['cover_letter_id'] as String?,
        notesText: j['notes_text'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'company_name': companyName,
        'role': role,
        'status': status.toApiString(),
        'location': location,
        'source_url': sourceUrl,
        'recruiter_name': recruiterName,
        'applied_date': appliedDate?.toIso8601String().split('T').first,
        'resume_version_id': resumeVersionId,
        'cover_letter_id': coverLetterId,
        'notes_text': notesText,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Application copyWith({ApplicationStatus? status, String? notesText}) =>
      Application(
        id: id,
        userId: userId,
        companyName: companyName,
        role: role,
        status: status ?? this.status,
        location: location,
        sourceUrl: sourceUrl,
        recruiterName: recruiterName,
        appliedDate: appliedDate,
        resumeVersionId: resumeVersionId,
        coverLetterId: coverLetterId,
        notesText: notesText ?? this.notesText,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

// ── Interview ──────────────────────────────────────────────────────────────────

class Interview {
  final String id;
  final String applicationId;
  final String userId;
  final String interviewType;
  final DateTime scheduledAt;
  final int? durationMinutes;
  final String? locationOrLink;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Interview({
    required this.id,
    required this.applicationId,
    required this.userId,
    required this.interviewType,
    required this.scheduledAt,
    this.durationMinutes,
    this.locationOrLink,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Interview.fromJson(Map<String, dynamic> j) => Interview(
        id: j['id'] as String,
        applicationId: j['application_id'] as String,
        userId: j['user_id'] as String,
        interviewType: j['interview_type'] as String,
        scheduledAt: DateTime.parse(j['scheduled_at'] as String),
        durationMinutes: j['duration_minutes'] as int?,
        locationOrLink: j['location_or_link'] as String?,
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}

// ── TimelineEvent ──────────────────────────────────────────────────────────────

class TimelineEvent {
  final String id;
  final String applicationId;
  final String userId;
  final String eventType;
  final String description;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const TimelineEvent({
    required this.id,
    required this.applicationId,
    required this.userId,
    required this.eventType,
    required this.description,
    this.metadata,
    required this.createdAt,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> j) => TimelineEvent(
        id: j['id'] as String,
        applicationId: j['application_id'] as String,
        userId: j['user_id'] as String,
        eventType: j['event_type'] as String,
        description: j['description'] as String,
        metadata: j['metadata'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
