import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/generation_model.dart';
import '../../../core/network/api_client.dart';

class GenerationRepository {
  final Dio _dio;
  GenerationRepository(this._dio);

  Future<GenerationResult> generateTailoredResume({
    required String resumeId,
    required String jobTitle,
    required String jobDescription,
    String? companyName,
    bool generateCoverLetter = true,
  }) async {
    final res = await _dio.post(
      '/generation/resumes/$resumeId/generate',
      data: {
        'job_title': jobTitle,
        'job_description': jobDescription,
        'company_name': companyName,
        'generate_cover_letter': generateCoverLetter,
      },
    );
    return GenerationResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CoverLetter> generateCoverLetter({
    String? resumeVersionId,
    required String jobTitle,
    required String jobDescription,
    String? companyName,
  }) async {
    final res = await _dio.post(
      '/generation/cover-letters',
      data: {
        'resume_version_id': resumeVersionId,
        'job_title': jobTitle,
        'job_description': jobDescription,
        'company_name': companyName,
      },
    );
    return CoverLetter.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CoverLetter> getCoverLetter(String id) async {
    final res = await _dio.get('/generation/cover-letters/$id');
    return CoverLetter.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CoverLetter> updateCoverLetter(String id, String content) async {
    final res = await _dio.patch(
      '/generation/cover-letters/$id',
      data: {'content': content},
    );
    return CoverLetter.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteCoverLetter(String id) async {
    await _dio.delete('/generation/cover-letters/$id');
  }
}

final generationRepositoryProvider = Provider<GenerationRepository>((ref) {
  return GenerationRepository(ref.watch(apiClientProvider).dio);
});

class GenerationNotifier extends StateNotifier<AsyncValue<GenerationResult?>> {
  final GenerationRepository _repo;

  GenerationNotifier(this._repo) : super(const AsyncData(null));

  Future<void> generate({
    required String resumeId,
    required String jobTitle,
    required String jobDescription,
    String? companyName,
    bool generateCoverLetter = true,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.generateTailoredResume(
        resumeId: resumeId,
        jobTitle: jobTitle,
        jobDescription: jobDescription,
        companyName: companyName,
        generateCoverLetter: generateCoverLetter,
      ),
    );
  }

  void reset() {
    state = const AsyncData(null);
  }
}

final generationProvider =
    StateNotifierProvider<GenerationNotifier, AsyncValue<GenerationResult?>>((ref) {
  return GenerationNotifier(ref.watch(generationRepositoryProvider));
});
