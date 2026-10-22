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

/// Files accepted by the picker and the number omitted by its safety limits.
typedef AttachmentSelection = ({List<File> files, int rejected});

/// Picks files to attach, capped so a single message cannot carry an unbounded
/// payload. Oversized or unreadable files are skipped individually and counted
/// so the compose screen can explain why they were omitted.
Future<AttachmentSelection> pickAttachmentFiles() async {
  final List<XFile> picked = await openFiles();
  final List<File> files = <File>[];
  int total = 0;
  int rejected = 0;

  for (int i = 0; i < picked.length; i++) {
    final XFile file = picked[i];
    if (files.length >= MailLimits.maxAttachmentCount) {
      rejected += picked.length - i;
      break;
    }

    final int size;
    try {
      size = await file.length();
    } catch (_) {
      // A selected file can disappear or become unreadable before it is
      // inspected. Skip it, but report the omission to the compose screen.
      rejected++;
      continue;
    }

    if (size < 0 || total + size > MailLimits.maxOutboundAttachmentBytes) {
      rejected++;
      continue;
    }
    total += size;
    files.add(File(file.path));
  }
  return (files: files, rejected: rejected);
}
