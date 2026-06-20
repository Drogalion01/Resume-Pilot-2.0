import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class InterviewData {
  final String id;
  final String applicationId;
  final String interviewType;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? locationOrLink;
  final String? notes;
  final bool reminderEnabled;

  InterviewData({
    required this.id,
    required this.applicationId,
    required this.interviewType,
    required this.scheduledAt,
    required this.durationMinutes,
    this.locationOrLink,
    this.notes,
    required this.reminderEnabled,
  });

  factory InterviewData.fromJson(Map<String, dynamic> j) => InterviewData(
        id: j['id'] as String,
        applicationId: j['application_id'] as String,
        interviewType: j['interview_type'] as String,
        scheduledAt: DateTime.parse(j['scheduled_at'] as String),
        durationMinutes: j['duration_minutes'] as int,
        locationOrLink: j['location_or_link'] as String?,
        notes: j['notes'] as String?,
        reminderEnabled: j['reminder_enabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'interview_type': interviewType,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        'location_or_link': locationOrLink,
        'notes': notes,
        'reminder_enabled': reminderEnabled,
      };
}

class InterviewRepository {
  final Dio _dio;
  InterviewRepository(this._dio);

  Future<List<InterviewData>> fetchInterviews(String appId) async {
    final res = await _dio.get('/applications/$appId/interviews');
    return (res.data as List).map((e) => InterviewData.fromJson(e)).toList();
  }

  Future<InterviewData> scheduleInterview(String appId, InterviewData data) async {
    final res = await _dio.post('/applications/$appId/interviews', data: data.toJson());
    return InterviewData.fromJson(res.data);
  }

  Future<void> deleteInterview(String interviewId) async {
    await _dio.delete('/interviews/$interviewId');
  }
}

final interviewRepositoryProvider = Provider<InterviewRepository>((ref) {
  return InterviewRepository(ref.watch(apiClientProvider).dio);
});

// A family provider to manage state of interviews for a given application
final applicationInterviewsProvider = AsyncNotifierProviderFamily<ApplicationInterviewsNotifier, List<InterviewData>, String>(
  ApplicationInterviewsNotifier.new,
);

class ApplicationInterviewsNotifier extends FamilyAsyncNotifier<List<InterviewData>, String> {
  @override
  Future<List<InterviewData>> build(String arg) {
    return ref.read(interviewRepositoryProvider).fetchInterviews(arg);
  }

  Future<InterviewData> schedule(InterviewData data) async {
    final saved = await ref.read(interviewRepositoryProvider).scheduleInterview(arg, data);
    state = AsyncData([...state.valueOrNull ?? [], saved]);
    return saved;
  }
}
