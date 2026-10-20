import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';

import '../data/limits.dart';
import '../util/file_names.dart';

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
    this.toEmails = '',
    this.ccEmails = '',
    required this.date,
    required this.textBody,
    required this.htmlBody,
    required this.attachments,
    this.skippedAttachments = 0,
    this.messageId,
    this.references,
  });

  final int uid;
  final String subject;
  final String fromName;
  final String fromEmail;
  final String toLine;
  final String ccLine;

  /// Raw addresses, for building a reply-all.
  final String toEmails;
  final String ccEmails;
  final DateTime? date;
  final String textBody;
  final String? htmlBody;
  final List<MailAttachment> attachments;

  /// How many attachments were left out because of the size and count limits.
  final int skippedAttachments;

  bool get hasHtml => htmlBody != null && htmlBody!.trim().isNotEmpty;

  static final RegExp _htmlTag = RegExp(
    r'<\s*(html|body|div|p|table|br|span|a|td|tr)\b',
    caseSensitive: false,
  );

  /// The HTML to render: the real HTML part when there is one, otherwise a
  /// plain-text body that is plainly HTML. Senders do mislabel these, and
  /// rendering tags as text is worse than trusting the shape of the content.
  String? get htmlSource {
    if (hasHtml) return htmlBody;
    if (textBody.contains('<') && _htmlTag.hasMatch(textBody)) return textBody;
    return null;
  }

  /// Used to thread a reply: the message being answered, and its chain.
  final String? messageId;
  final String? references;

  factory FullMessage.fromMime(MimeMessage message) {
    final MailAddress? from =
        (message.from != null && message.from!.isNotEmpty)
            ? message.from!.first
            : null;

    final List<MailAttachment> attachments = <MailAttachment>[];
    int total = 0;
    int skipped = 0;

    for (final ContentInfo info in message.findContentInfo()) {
      if (attachments.length >= MailLimits.maxAttachmentCount) {
        skipped++;
        continue;
      }

      // Check the declared size before decoding: decoding first would already
      // have spent the memory the limit exists to protect.
      final int? declared = info.size;
      if (declared != null && declared > MailLimits.maxAttachmentBytes) {
        skipped++;
        continue;
      }

      final Uint8List? bytes =
          message.getPart(info.fetchId)?.decodeContentBinary();
      if (bytes == null || bytes.isEmpty) continue;
      if (bytes.length > MailLimits.maxAttachmentBytes ||
          total + bytes.length > MailLimits.maxTotalAttachmentBytes) {
        skipped++;
        continue;
      }
      total += bytes.length;

      attachments.add(
        MailAttachment(
          fileName: sanitizeFileName(info.fileName ?? 'attachment'),
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
      toEmails: _emails(message.to),
      ccEmails: _emails(message.cc),
      date: message.decodeDate(),
      textBody: message.decodeTextPlainPart() ?? '',
      htmlBody: _capped(message.decodeTextHtmlPart()),
      attachments: attachments,
      skippedAttachments: skipped,
      messageId: message.getHeaderValue('message-id'),
      references: message.getHeaderValue('references'),
    );
  }

  /// Truncate a body that is absurdly large rather than parse all of it.
  static String? _capped(String? html) {
    if (html == null) return null;
    if (html.length <= MailLimits.maxHtmlBytes) return html;
    return html.substring(0, MailLimits.maxHtmlBytes);
  }

  static String _emails(List<MailAddress>? list) => list == null
      ? ''
      : list
          .map((MailAddress a) => a.email)
          .where((String s) => s.isNotEmpty)
          .join(', ');

  static String _addresses(List<MailAddress>? list) => list == null
      ? ''
      : list
          .map((MailAddress a) => a.personalName ?? a.email)
          .where((String s) => s.isNotEmpty)
          .join(', ');
}
