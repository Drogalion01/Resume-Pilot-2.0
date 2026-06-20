import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/application_model.dart';
import '../../../core/network/api_client.dart';

class ApplicationRepository {
  final Dio _dio;
  ApplicationRepository(this._dio);

  Future<List<Application>> fetchApplications() async {
    final res = await _dio.get('/applications/');
    return (res.data as List).map((e) => Application.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Application> fetchApplication(String id) async {
    final res = await _dio.get('/applications/$id');
    return Application.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Application> createApplication({
    required String companyName,
    required String role,
    required String status,
    String? location,
    String? sourceUrl,
    String? recruiterName,
  }) async {
    final res = await _dio.post('/applications/', data: {
      'company_name': companyName,
      'role': role,
      'status': status,
      'location': location,
      'source_url': sourceUrl,
      'recruiter_name': recruiterName,
    });
    return Application.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Application> updateApplication(String id, Map<String, dynamic> updates) async {
    final res = await _dio.patch('/applications/$id', data: updates);
    return Application.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteApplication(String id) async {
    await _dio.delete('/applications/$id');
  }

  Future<List<TimelineEvent>> fetchTimeline(String applicationId) async {
    final res = await _dio.get('/applications/$applicationId/timeline');
    return (res.data as List).map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>)).toList();
  }
}

final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  return ApplicationRepository(ref.watch(apiClientProvider).dio);
});

final applicationListProvider = AsyncNotifierProvider<ApplicationListNotifier, List<Application>>(
  ApplicationListNotifier.new,
);

class ApplicationListNotifier extends AsyncNotifier<List<Application>> {
  @override
  Future<List<Application>> build() => ref.read(applicationRepositoryProvider).fetchApplications();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(applicationRepositoryProvider).fetchApplications(),
    );
  }

  Future<void> addApplication(Application app) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([app, ...current]);
  }

  Future<void> updateApplicationInList(Application updated) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.map((a) => a.id == updated.id ? updated : a).toList());
  }

  Future<void> removeApplication(String id) async {
    final current = state.valueOrNull ?? [];
    await ref.read(applicationRepositoryProvider).deleteApplication(id);
    state = AsyncData(current.where((a) => a.id != id).toList());
  }
}

final applicationDetailProvider = FutureProvider.family<Application, String>((ref, id) {
  return ref.read(applicationRepositoryProvider).fetchApplication(id);
});

final applicationTimelineProvider = FutureProvider.family<List<TimelineEvent>, String>((ref, id) {
  return ref.read(applicationRepositoryProvider).fetchTimeline(id);
});
