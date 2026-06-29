// lib/core/services/pdf_download_stub.dart
//
// Stub implementation used on mobile/desktop platforms.
// path_provider + open_file save the PDF and open it natively.

import 'dart:io';
import 'dart:typed_data';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

Future<void> triggerPdfDownload(Uint8List bytes, String filename) async {
  // Save to the app's documents directory (or downloads if available)
  Directory? dir;
  try {
    // Try Downloads directory first (Android only, may not exist)
    dir = Directory('/storage/emulated/0/Download');
    if (!dir.existsSync()) dir = null;
  } catch (_) {}

  dir ??= await getApplicationDocumentsDirectory();

  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  await OpenFile.open(file.path);
}
