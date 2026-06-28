import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show AnchorElement, Url, Blob;
import 'dart:typed_data';

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

/// Triggers a web browser download from [bytes] with [filename].
/// No-op on non-web platforms (caller should use path_provider there).
void downloadBytesOnWeb(Uint8List bytes, String filename) {
  if (!kIsWeb) return;
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// Download state notifier for resume PDF
enum DownloadStatus { idle, loading, done, error }

class PdfDownloadNotifier extends StateNotifier<DownloadStatus> {
  final GenerationRepository _repo;
  PdfDownloadNotifier(this._repo) : super(DownloadStatus.idle);

  Future<void> downloadResume(String resumeVersionId, String filename) async {
    state = DownloadStatus.loading;
    try {
      final bytes = await _repo.downloadResumePdf(resumeVersionId);
      if (kIsWeb) {
        downloadBytesOnWeb(bytes, filename);
      }
      // TODO: on mobile, save with path_provider + open_file
      state = DownloadStatus.done;
    } catch (e) {
      state = DownloadStatus.error;
    }
  }

  Future<void> downloadCoverLetter(String coverLetterId, String filename) async {
    state = DownloadStatus.loading;
    try {
      final bytes = await _repo.downloadCoverLetterPdf(coverLetterId);
      if (kIsWeb) {
        downloadBytesOnWeb(bytes, filename);
      }
      state = DownloadStatus.done;
    } catch (e) {
      state = DownloadStatus.error;
    }
  }

  void reset() => state = DownloadStatus.idle;
}

final pdfDownloadProvider =
    StateNotifierProvider<PdfDownloadNotifier, DownloadStatus>((ref) {
  return PdfDownloadNotifier(ref.watch(generationRepositoryProvider));
});
