import 'package:enough_mail/enough_mail.dart';

import '../util/initials.dart';
import '../util/otp.dart';

/// A lightweight row in the message list. Holds only what the list renders so
/// listing a folder never downloads message bodies.
class MessageSummary {
  const MessageSummary({
    required this.uid,
    required this.sequenceId,
    required this.subject,
    required this.fromName,
    required this.fromEmail,
    required this.date,
    required this.isSeen,
    required this.isFlagged,
    this.hasAttachments = false,
    this.otp,
    this.folderPath,
  });

  final int uid;
  final int sequenceId;

  /// The mailbox that owns this UID. UIDs are only unique within a mailbox.
  /// Nullable for older callers that construct summaries outside a folder load.
  final String? folderPath;
  final String subject;
  final String fromName;
  final String fromEmail;
  final DateTime? date;
  final bool isSeen;
  final bool isFlagged;

  /// Whether the message carries something attached.
  ///
  /// Read from the structure the server already sent with the envelope, so it
  /// costs nothing — which is the only reason a list row can say it at all.
  final bool hasAttachments;

  /// A one-time code, when the subject carries one. The body is searched later,
  /// and only for the mail that needs it.
  final String? otp;

  factory MessageSummary.fromMime(
    MimeMessage message, {
    String? folderPath,
  }) {
    final MailAddress? from =
        (message.from != null && message.from!.isNotEmpty)
            ? message.from!.first
            : null;
    final String subject = message.decodeSubject() ?? '(no subject)';
    // The subject is free — it is already here — so it is checked as the row is
    // built, and the body is only fetched for the ones this misses.
    final String? code = OtpDetector.find(subject);

    return MessageSummary(
      uid: message.uid ?? 0,
      sequenceId: message.sequenceId ?? 0,
      folderPath: folderPath,
      subject: subject,
      fromName: from?.personalName ?? from?.email ?? '(unknown sender)',
      fromEmail: from?.email ?? '',
      date: message.decodeDate(),
      // The flag as well as the property. enough_mail's `isSeen` reads the
      // *parsed message's* flags, and on a fetch that asks for envelopes rather
      // than full messages it can come back false for mail that has been read —
      // which showed every row as unread while the folder's own count, which
      // comes from the server's STATUS, said there was nothing unread at all.
      isSeen: message.isSeen ||
          (message.flags?.contains(MessageFlags.seen) ?? false),
      isFlagged: message.isFlagged,
      hasAttachments: message.hasAttachments(),
      otp: code,
    );
  }

  MessageSummary copyWith({
    bool? isSeen,
    bool? isFlagged,
    bool? hasAttachments,
    String? otp,
  }) =>
      MessageSummary(
        uid: uid,
        sequenceId: sequenceId,
        folderPath: folderPath,
        subject: subject,
        fromName: fromName,
        fromEmail: fromEmail,
        date: date,
        isSeen: isSeen ?? this.isSeen,
        isFlagged: isFlagged ?? this.isFlagged,
        hasAttachments: hasAttachments ?? this.hasAttachments,
        otp: otp ?? this.otp,
      );

  /// Two letters for the avatar chip, derived from the display name.
  String get initials => initialsFor(fromName, fromEmail);
}
