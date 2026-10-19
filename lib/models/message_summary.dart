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
  });

  final int uid;
  final int sequenceId;
  final String subject;
  final String fromName;
  final String fromEmail;
  final DateTime? date;
  final bool isSeen;

  factory MessageSummary.fromMime(MimeMessage message) {
    final MailAddress? from = (message.from != null && message.from!.isNotEmpty)
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
    );
  }

  MessageSummary copyWith({bool? isSeen}) => MessageSummary(
        uid: uid,
        sequenceId: sequenceId,
        subject: subject,
        fromName: fromName,
        fromEmail: fromEmail,
        date: date,
        isSeen: isSeen ?? this.isSeen,
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
