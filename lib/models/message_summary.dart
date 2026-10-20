import 'package:enough_mail/enough_mail.dart';

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
  });

  final int uid;
  final int sequenceId;
  final String subject;
  final String fromName;
  final String fromEmail;
  final DateTime? date;
  final bool isSeen;
  final bool isFlagged;

  factory MessageSummary.fromMime(MimeMessage message) {
    final MailAddress? from =
        (message.from != null && message.from!.isNotEmpty)
            ? message.from!.first
            : null;
    return MessageSummary(
      uid: message.uid ?? 0,
      sequenceId: message.sequenceId ?? 0,
      subject: message.decodeSubject() ?? '(no subject)',
      fromName: from?.personalName ?? from?.email ?? '(unknown sender)',
      fromEmail: from?.email ?? '',
      date: message.decodeDate(),
      isSeen: message.isSeen,
      isFlagged: message.isFlagged,
    );
  }

  MessageSummary copyWith({bool? isSeen, bool? isFlagged}) => MessageSummary(
        uid: uid,
        sequenceId: sequenceId,
        subject: subject,
        fromName: fromName,
        fromEmail: fromEmail,
        date: date,
        isSeen: isSeen ?? this.isSeen,
        isFlagged: isFlagged ?? this.isFlagged,
      );

  /// Two letters for the avatar chip, derived from the display name.
  String get initials {
    final String source = fromName.trim();
    if (source.isEmpty) return '?';
    final List<String> parts = source.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
