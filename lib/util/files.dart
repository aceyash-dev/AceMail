import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// Asks for a destination and writes [bytes] there. Returns the written path,
/// or null when the user cancels.
Future<String?> saveAttachmentFile(
  String suggestedName,
  Uint8List bytes,
) async {
  final FileSaveLocation? location = await getSaveLocation(
    suggestedName: suggestedName,
  );
  if (location == null) return null;
  final File file = File(location.path);
  await file.writeAsBytes(bytes);
  return file.path;
}

/// Opens the platform picker for attachments. Returns an empty list on cancel.
Future<List<XFile>> pickAttachmentFiles() => openFiles();
