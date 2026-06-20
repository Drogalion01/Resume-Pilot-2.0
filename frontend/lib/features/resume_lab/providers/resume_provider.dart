// lib/features/resume_lab/providers/resume_provider.dart
//
// Riverpod providers for Resume Lab.
// Pattern: Repository class → AsyncNotifier for mutable list state.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/resume_model.dart';
import '../../../core/network/api_client.dart';

// ── Repository ──────────────────────────────────────────────────────────────────

class ResumeRepository {
  final Dio _dio;
  ResumeRepository(this._dio);

  Future<List<Resume>> fetchResumes() async {
    final res = await _dio.get('/resumes/');
    return (res.data as List).map((e) => Resume.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Resume> fetchResume(String id) async {
    final res = await _dio.get('/resumes/$id');
    return Resume.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Resume> uploadResume({
    required String filePath,
    required String title,
    required bool isMaster,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'title': title,
      'is_master': isMaster.toString(),
    });
    final res = await _dio.post('/resumes/', data: formData);
    return Resume.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteResume(String id) => _dio.delete('/resumes/$id');

  Future<List<ResumeVersion>> fetchVersions(String resumeId) async {
    final res = await _dio.get('/resumes/$resumeId/versions');
    return (res.data as List)
        .map((e) => ResumeVersion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AnalysisResult> analyzeResume(String resumeId) async {
    final res = await _dio.post('/resumes/$resumeId/analyze');
    return AnalysisResult.fromJson(res.data as Map<String, dynamic>);
  }
}

// ── Providers ───────────────────────────────────────────────────────────────────

final resumeRepositoryProvider = Provider<ResumeRepository>((ref) {
  final dio = ref.watch(apiClientProvider).dio;
  return ResumeRepository(dio);
});

/// Async list of all resumes — used by resume list screen
final resumeListProvider = AsyncNotifierProvider<ResumeListNotifier, List<Resume>>(
  ResumeListNotifier.new,
);

class ResumeListNotifier extends AsyncNotifier<List<Resume>> {
  @override
  Future<List<Resume>> build() => ref.read(resumeRepositoryProvider).fetchResumes();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(resumeRepositoryProvider).fetchResumes(),
    );
  }

  Future<void> addResume(Resume resume) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData([resume, ...current]);
  }

  Future<void> removeResume(String id) async {
    final current = state.valueOrNull ?? [];
    await ref.read(resumeRepositoryProvider).deleteResume(id);
    state = AsyncData(current.where((r) => r.id != id).toList());
  }
}

/// Single resume detail — fetched by ID
final resumeDetailProvider =
    FutureProvider.family<Resume, String>((ref, id) {
  return ref.read(resumeRepositoryProvider).fetchResume(id);
});

/// Resume versions list
final resumeVersionsProvider =
    FutureProvider.family<List<ResumeVersion>, String>((ref, resumeId) {
  return ref.read(resumeRepositoryProvider).fetchVersions(resumeId);
});

/// On-demand analysis — triggered imperatively, cached here
final resumeAnalysisProvider =
    StateProvider.family<AnalysisResult?, String>((ref, resumeId) => null);
