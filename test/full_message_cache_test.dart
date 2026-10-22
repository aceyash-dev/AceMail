import 'dart:convert';
import 'dart:typed_data';

import 'package:ace_mail/models/full_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// A cached message has to come back **whole**. A cache that quietly loses a
/// body — or an attachment — is worse than no cache, because the loss is
/// invisible until it matters.
void main() {
  final FullMessage message = FullMessage(
    uid: 42,
    subject: 'Your code',
    fromName: 'Bank',
    fromEmail: 'no-reply@bank.example',
    toLine: 'Yash <yash@example.com>',
    ccLine: 'Other <other@example.com>',
    toEmails: 'yash@example.com',
    ccEmails: 'other@example.com',
    date: DateTime.utc(2026, 10, 22, 9, 30),
    textBody: 'Your code is 123456',
    htmlBody: '<p>Your code is <b>123456</b></p>',
    attachments: const <MailAttachment>[],
    messageId: '<abc@bank.example>',
    references: '<parent@bank.example>',
    rawHeaders: 'From: no-reply@bank.example\nSubject: Your code',
  );

  group('FullMessage cache round trip', () {
    test('comes back as it went in', () {
      final FullMessage? restored = FullMessage.fromCache(message.toCache());

      expect(restored, isNotNull);
      expect(restored!.uid, message.uid);
      expect(restored.subject, message.subject);
      expect(restored.fromName, message.fromName);
      expect(restored.fromEmail, message.fromEmail);
      expect(restored.toLine, message.toLine);
      expect(restored.ccLine, message.ccLine);
      expect(restored.toEmails, message.toEmails);
      expect(restored.ccEmails, message.ccEmails);
      expect(restored.date, message.date);
      expect(restored.textBody, message.textBody);
      expect(restored.htmlBody, message.htmlBody);
      expect(restored.messageId, message.messageId);
      expect(restored.references, message.references);
      expect(restored.rawHeaders, message.rawHeaders);
      expect(restored.attachments, isEmpty);
    });

    test('a plain-text message with no HTML stays that way', () {
      final FullMessage plain = FullMessage(
        uid: 1,
        subject: 's',
        fromName: 'n',
        fromEmail: 'e@example.com',
        toLine: '',
        ccLine: '',
        date: null,
        textBody: 'just text',
        htmlBody: null,
        attachments: const <MailAttachment>[],
      );
      final FullMessage? restored = FullMessage.fromCache(plain.toCache());
      expect(restored!.htmlBody, isNull);
      expect(restored.htmlSource, isNull);
      expect(restored.date, isNull);
    });

    test('what is written is JSON, because that is what the store writes', () {
      expect(() => jsonEncode(message.toCache()), returnsNormally);
    });

    test('a message with attachments is not cacheable', () {
      final FullMessage withAttachment = FullMessage(
        uid: 2,
        subject: 's',
        fromName: 'n',
        fromEmail: 'e@example.com',
        toLine: '',
        ccLine: '',
        date: null,
        textBody: 'see attached',
        htmlBody: null,
        attachments: <MailAttachment>[
          MailAttachment(
            fileName: 'notes.pdf',
            mediaType: 'application/pdf',
            bytes: Uint8List.fromList(<int>[1, 2, 3]),
          ),
        ],
      );
      expect(withAttachment.isCacheable, isFalse);
      expect(message.isCacheable, isTrue);
    });

    test('a record that is not a message is refused, not guessed at', () {
      expect(FullMessage.fromCache(<String, Object?>{}), isNull);
      expect(
        FullMessage.fromCache(<String, Object?>{
          'uid': 'not an int',
          'subject': 's',
          'text': 't',
        }),
        isNull,
      );
      expect(
        FullMessage.fromCache(<String, Object?>{'uid': 1, 'subject': 's'}),
        isNull,
      );
    });
  });
}
