import '../data/limits.dart';

/// A filename that is safe to hand to the platform save dialog.
///
/// Attachment names come from the message, which means they come from whoever
/// sent it. Strip anything that could escape the chosen directory or confuse
/// the dialog before it is ever used as a suggestion. The save dialog remains
/// the final authority on where the file lands.
String sanitizeFileName(String raw) {
  final String cleaned = raw
      .replaceAll(RegExp(r'[\\/]'), '_')
      .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '')
      .replaceAll(RegExp(r'^\.+'), '')
      .trim();

  final String capped = cleaned.length > MailLimits.maxFileNameLength
      ? cleaned.substring(0, MailLimits.maxFileNameLength)
      : cleaned;

  return capped.isEmpty ? 'attachment' : capped;
}
