import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/limits.dart';
import 'file_names.dart';

/// Asks for a destination and writes [bytes] there. Returns the written path,
/// or null when the person cancels.
///
/// iOS has no save dialog for a plugin to open. Its way to put a file somewhere
/// is the share sheet's *Save to Files*, so there the bytes go to a short-lived
/// copy, the sheet is shown, and the copy is removed afterwards. On iOS the
/// return value is the file's name, since the place it lands is the person's
/// choice inside the sheet.
///
/// [sharePositionOrigin] is where the sheet points on an iPad. Without it the
/// sheet cannot be shown there at all, so the caller passes the tapped widget's
/// rectangle.
Future<String?> saveAttachmentFile(
  String suggestedName,
  Uint8List bytes, {
  Rect? sharePositionOrigin,
}) async {
  final String name = sanitizeFileName(suggestedName);
  if (Platform.isIOS) {
    return _saveThroughShareSheet(name, bytes, sharePositionOrigin);
  }

  final FileSaveLocation? location = await getSaveLocation(suggestedName: name);
  if (location == null) return null;
  final File file = File(location.path);
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<String?> _saveThroughShareSheet(
  String name,
  Uint8List bytes,
  Rect? origin,
) async {
  final Directory temporary = await getTemporaryDirectory();
  final File copy = File('${temporary.path}/$name');
  await copy.writeAsBytes(bytes);
  try {
    final ShareResult result = await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(copy.path, name: name)],
        sharePositionOrigin: origin,
      ),
    );
    switch (result.status) {
      case ShareResultStatus.success:
        return name;
      case ShareResultStatus.dismissed:
        return null;
      case ShareResultStatus.unavailable:
        throw StateError('The share sheet could not be opened.');
    }
  } finally {
    // The copy holds the attachment unencrypted, and it is only needed for as
    // long as the sheet is open. Removed either way; a failure to remove it is
    // not worth reporting over the save itself.
    try {
      await copy.delete();
    } on FileSystemException {
      // Already gone.
    }
  }
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
/// [alreadyCount] is how many files the message already carries, so the cap is
/// the *message's* cap and not this dialog's. Picking ten files three times
/// used to be allowed, because each dialog only counted its own.
///
/// [choose] is injectable so both caps can be tested without a file dialog.
Future<PickedAttachments> pickAttachmentFiles({
  Future<List<XFile>> Function()? choose,
  int alreadyCount = 0,
}) async {
  final List<XFile> picked = await (choose ?? openFiles)();
  final List<File> files = <File>[];
  int skipped = 0;
  final int room = MailLimits.maxAttachmentCount - alreadyCount;

  for (final XFile file in picked) {
    if (files.length >= room) {
      // Counted, not just dropped: the screen reports what it left off.
      skipped++;
      continue;
    }
    files.add(File(file.path));
  }
  return (files: files, skipped: skipped);
}
