/// Limits that keep a hostile or merely enormous message from taking the app
/// down with it.
///
/// Deliberately conservative and all in one place, so they can be tuned without
/// hunting through the code.
abstract final class MailLimits {
  /// Largest HTML body we will parse. Anything beyond is truncated.
  static const int maxHtmlBytes = 2 * 1024 * 1024;

  /// How many bodies are fetched per page while looking for one-time codes.
  static const int codeLookups = 12;

  /// How much of a body is fetched when looking for a one-time code.
  static const int previewBytes = 4096;

  /// Largest single attachment we will decode into memory.
  static const int maxAttachmentBytes = 25 * 1024 * 1024;

  /// Largest total of decoded attachments for one message.
  static const int maxTotalAttachmentBytes = 40 * 1024 * 1024;

  /// Most attachments we will decode from one message.
  static const int maxAttachmentCount = 20;

  /// Largest total of files attached to one outgoing message.
  static const int maxOutboundAttachmentBytes = 25 * 1024 * 1024;

  /// Longest attachment filename we will suggest to the save dialog.
  static const int maxFileNameLength = 120;

  /// How many message UIDs we hold for a folder. Folders larger than this show
  /// their most recent messages rather than pulling every UID the server has.
  static const int maxFolderUids = 2000;
}
