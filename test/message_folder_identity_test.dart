import 'package:ace_mail/models/message_summary.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageSummary mailbox identity', () {
    test('fromMime and copyWith preserve the owning folder', () {
      final MimeMessage message = MimeMessage.parseFromText(
        'From: Priya Sharma <priya@example.com>\r\n'
        'Subject: Hello\r\n'
        '\r\n'
        'body\r\n',
      );

      final MessageSummary summary =
          MessageSummary.fromMime(message, folderPath: 'Archive');

      expect(summary.folderPath, 'Archive');
      expect(summary.copyWith(isSeen: true).folderPath, 'Archive');
    });

    test('legacy constructors remain compatible', () {
      const MessageSummary summary = MessageSummary(
        uid: 1,
        sequenceId: 1,
        subject: 'Hello',
        fromName: 'Priya',
        fromEmail: 'priya@example.com',
        date: null,
        isSeen: false,
        isFlagged: false,
      );

      expect(summary.folderPath, isNull);
    });
  });
}
