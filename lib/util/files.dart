import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

import '../data/limits.dart';
import 'file_names.dart';

/// Asks for a destination and writes [bytes] there. Returns a line saying where
/// the file went, or null when the person cancels.
///
/// iOS has no save dialog for a plugin to open. Its place for a person's own
/// files is the Files app, and an app puts files there by keeping them in its
/// documents folder with file sharing turned on, which
/// tool/ios/configure_ios.py sets. So on iOS the attachment lands in Ace Mail's
/// folder in the Files app, under a name that does not overwrite an earlier
/// save, and the returned line names that place.
Future<String?> saveAttachmentFile(
  String suggestedName,
  Uint8List bytes,
) async {
  final String name = sanitizeFileName(suggestedName);
  if (Platform.isIOS) return _saveToFilesApp(name, bytes);

  final FileSaveLocation? location = await getSaveLocation(suggestedName: name);
  if (location == null) return null;
  final File file = File(location.path);
  await file.writeAsBytes(bytes);
  return file.path;
}

/// The line the Files app shows for Ace Mail's folder, with a separator that
/// reads the same way the Files app's own breadcrumbs do.
const String _filesAppPlace = 'Files \u203A Ace Mail';

Future<String> _saveToFilesApp(String name, Uint8List bytes) async {
  final Directory documents = await getApplicationDocumentsDirectory();
  final File file = _freeName(documents, name);
  await file.writeAsBytes(bytes);
  final String saved = file.uri.pathSegments.last;
  return '$_filesAppPlace \u203A $saved';
}

/// A file in [folder] called [name], or the first "name (2).ext", "name (3).ext"
/// that is free. An earlier save is never overwritten.
File _freeName(Directory folder, String name) {
  final int dot = name.lastIndexOf('.');
  final String stem = dot > 0 ? name.substring(0, dot) : name;
  final String extension = dot > 0 ? name.substring(dot) : '';
  File candidate = File('${folder.path}/$name');
  int copy = 2;
  while (candidate.existsSync()) {
    candidate = File('${folder.path}/$stem ($copy)$extension');
    copy++;
  }
  return candidate;
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
