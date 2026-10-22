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

/// What the picker chose, and how many files the count cap left off.
typedef PickedAttachments = ({List<File> files, int skipped});

/// Picks files to attach.
///
/// The picker enforces the **count** cap and nothing else. The **byte** cap
/// belongs to [planAttachments], which skips an oversized file individually and
/// reports it, so one big file does not discard the smaller ones picked behind
/// it — and the compose screen can say what was left off. Doing the byte cap
/// here as well used to stop the whole selection at the first file that did not
/// fit, and the screen had no way to mention the files it had already dropped.
///
/// [choose] is injectable so both caps can be tested without a file dialog.
Future<PickedAttachments> pickAttachmentFiles({
  Future<List<XFile>> Function()? choose,
}) async {
  final List<XFile> picked = await (choose ?? openFiles)();
  final List<File> files = <File>[];
  int skipped = 0;

  for (final XFile file in picked) {
    if (files.length >= MailLimits.maxAttachmentCount) {
      // Counted, not just dropped: the screen reports what it left off.
      skipped++;
      continue;
    }
    files.add(File(file.path));
  }
  return (files: files, skipped: skipped);
}
