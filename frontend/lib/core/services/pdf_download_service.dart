// lib/core/services/pdf_download_service.dart
//
// Platform-aware PDF download service using conditional imports.
// The compiler picks the correct implementation at build time:
//   - Web → pdf_download_web.dart  (dart:html blob + anchor click)
//   - Mobile/Desktop → pdf_download_stub.dart  (path_provider + open_file)
//
// Usage:
//   await PdfDownloadService.save(bytes, 'tailored_resume.pdf');

import 'dart:typed_data';

import 'pdf_download_stub.dart'
    if (dart.library.html) 'pdf_download_web.dart';

class PdfDownloadService {
  PdfDownloadService._();

  /// Save [bytes] as [filename] and trigger the platform-appropriate action:
  ///   - **Web**: triggers browser "Save As" dialog
  ///   - **Android/iOS**: saves to device storage and opens in native viewer
  ///   - **Desktop**: saves to Documents and opens with system PDF viewer
  static Future<void> save(Uint8List bytes, String filename) =>
      triggerPdfDownload(bytes, filename);
}
