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
    this.otp,
  });

  final int uid;
  final int sequenceId;
  final String subject;
  final String fromName;
  final String fromEmail;
  final DateTime? date;
  final bool isSeen;
  final bool isFlagged;

  /// A one-time code, when the subject carries one. The body is searched later,
  /// and only for the mail that needs it.
  final String? otp;

  factory MessageSummary.fromMime(MimeMessage message) {
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
      subject: subject,
      fromName: from?.personalName ?? from?.email ?? '(unknown sender)',
      fromEmail: from?.email ?? '',
      date: message.decodeDate(),
      isSeen: message.isSeen,
      isFlagged: message.isFlagged,
      otp: code,
    );
  }

  MessageSummary copyWith({bool? isSeen, bool? isFlagged, String? otp}) =>
      MessageSummary(
        uid: uid,
        sequenceId: sequenceId,
        subject: subject,
        fromName: fromName,
        fromEmail: fromEmail,
        date: date,
        isSeen: isSeen ?? this.isSeen,
        isFlagged: isFlagged ?? this.isFlagged,
        otp: otp ?? this.otp,
      );

  /// Two letters for the avatar chip, derived from the display name.
  String get initials => initialsFor(fromName, fromEmail);
}
