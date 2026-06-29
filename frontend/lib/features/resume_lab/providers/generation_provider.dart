import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';

import '../../../core/models/generation_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/pdf_download_service.dart';

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

  /// Download tailored resume as PDF.
  /// On web: triggers browser download. On other platforms: returns bytes for saving.
  Future<Uint8List> downloadResumePdf(String resumeVersionId) async {
    final res = await _dio.get<List<int>>(
      '/generation/resume-versions/$resumeVersionId/download-pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data!);
  }

  /// Download cover letter as PDF.
  Future<Uint8List> downloadCoverLetterPdf(String coverLetterId) async {
    final res = await _dio.get<List<int>>(
      '/generation/cover-letters/$coverLetterId/download-pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data!);
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

// ── PDF download helper ───────────────────────────────────────────────────────

enum DownloadStatus { idle, loading, done, error }

class PdfDownloadState {
  final DownloadStatus status;
  final String? errorMessage;
  const PdfDownloadState({this.status = DownloadStatus.idle, this.errorMessage});

  PdfDownloadState copyWith({DownloadStatus? status, String? errorMessage}) =>
      PdfDownloadState(
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class PdfDownloadNotifier extends StateNotifier<PdfDownloadState> {
  final GenerationRepository _repo;
  PdfDownloadNotifier(this._repo) : super(const PdfDownloadState());

  Future<void> downloadResume(String resumeVersionId, String filename) async {
    state = state.copyWith(status: DownloadStatus.loading);
    try {
      final bytes = await _repo.downloadResumePdf(resumeVersionId);
      await PdfDownloadService.save(bytes, filename);
      state = state.copyWith(status: DownloadStatus.done);
    } catch (e) {
      state = state.copyWith(
        status: DownloadStatus.error,
        errorMessage: 'Failed to download resume: ${_friendlyError(e)}',
      );
    }
  }

  Future<void> downloadCoverLetter(String coverLetterId, String filename) async {
    state = state.copyWith(status: DownloadStatus.loading);
    try {
      final bytes = await _repo.downloadCoverLetterPdf(coverLetterId);
      await PdfDownloadService.save(bytes, filename);
      state = state.copyWith(status: DownloadStatus.done);
    } catch (e) {
      state = state.copyWith(
        status: DownloadStatus.error,
        errorMessage: 'Failed to download cover letter: ${_friendlyError(e)}',
      );
    }
  }

  void reset() => state = const PdfDownloadState();

  String _friendlyError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 404) return 'File not found on server';
      if (code == 500) return 'Server error — try again shortly';
      return 'Network error';
    }
    return e.toString();
  }
}

final pdfDownloadProvider =
    StateNotifierProvider<PdfDownloadNotifier, PdfDownloadState>((ref) {
  return PdfDownloadNotifier(ref.watch(generationRepositoryProvider));
});
