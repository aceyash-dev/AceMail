import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../data/limits.dart';
import 'file_names.dart';

/// Asks for a destination and writes [bytes] there. Returns the written path,
/// or null when the user cancels.
Future<String?> saveAttachmentFile(
  String suggestedName,
  Uint8List bytes,
) async {
  final FileSaveLocation? location =
      await getSaveLocation(suggestedName: sanitizeFileName(suggestedName));
  if (location == null) return null;
  final File file = File(location.path);
  await file.writeAsBytes(bytes);
  return file.path;
}

/// Picks files to attach, capped so a single message cannot carry an unbounded
/// payload.
Future<List<File>> pickAttachmentFiles() async {
  final List<XFile> picked = await openFiles();
  final List<File> files = <File>[];
  int total = 0;

  for (final XFile file in picked) {
    if (files.length >= MailLimits.maxAttachmentCount) break;
    final int size = await file.length();
    if (total + size > MailLimits.maxOutboundAttachmentBytes) continue;
    total += size;
    files.add(File(file.path));
  }
  return files;
}
