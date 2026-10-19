import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';

class MailAttachment {
  const MailAttachment({
    required this.fileName,
    required this.mediaType,
    required this.bytes,
  });

  final String fileName;
  final String mediaType;
  final Uint8List bytes;

  int get size => bytes.length;
}

/// A fully loaded message: headers, both body representations, and any
/// attachments already decoded.
class FullMessage {
  const FullMessage({
    required this.uid,
    required this.subject,
    required this.fromName,
    required this.fromEmail,
    required this.toLine,
    required this.ccLine,
    required this.date,
    required this.textBody,
    required this.htmlBody,
    required this.attachments,
  });

  final int uid;
  final String subject;
  final String fromName;
  final String fromEmail;
  final String toLine;
  final String ccLine;
  final DateTime? date;
  final String textBody;
  final String? htmlBody;
  final List<MailAttachment> attachments;

  bool get hasHtml => htmlBody != null && htmlBody!.trim().isNotEmpty;

  factory FullMessage.fromMime(MimeMessage message) {
    final MailAddress? from = (message.from != null && message.from!.isNotEmpty)
        ? message.from!.first
        : null;

    final List<MailAttachment> attachments = [];
    for (final ContentInfo info in message.findContentInfo()) {
      final String? fetchId = info.fetchId;
      if (fetchId == null) continue;
      final Uint8List? bytes = message.getPart(fetchId)?.decodeContentBinary();
      if (bytes == null || bytes.isEmpty) continue;
      attachments.add(
        MailAttachment(
          fileName: info.fileName ?? 'attachment',
          mediaType: info.mediaType?.text ?? 'application/octet-stream',
          bytes: bytes,
        ),
      );
    }

    return FullMessage(
      uid: message.uid ?? 0,
      subject: message.decodeSubject() ?? '(no subject)',
      fromName: from?.personalName ?? from?.email ?? '(unknown sender)',
      fromEmail: from?.email ?? '',
      toLine: _addresses(message.to),
      ccLine: _addresses(message.cc),
      date: message.decodeDate(),
      textBody: message.decodeTextPlainPart() ?? '',
      htmlBody: message.decodeTextHtmlPart(),
      attachments: attachments,
    );
  }

  static String _addresses(List<MailAddress>? list) {
    if (list == null || list.isEmpty) return '';
    return list.map((MailAddress a) => a.personalName ?? a.email).join(', ');
  }
}
