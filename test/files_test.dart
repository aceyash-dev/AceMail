import 'dart:io';

import 'package:ace_mail/data/limits.dart';
import 'package:ace_mail/util/files.dart';
import 'package:ace_mail/util/file_names.dart';
import 'package:ace_mail/util/text.dart';
import 'package:ace_mail/models/contact.dart';
import 'package:ace_mail/models/message_summary.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';

/// The picker takes the dialog's result and applies the **count** cap. It
/// deliberately does not apply the byte cap — [planAttachments] does that,
/// skipping an oversized file individually — so these tests pin that split,
/// because getting it wrong is how an attachment silently goes missing.
void main() {
  group('pickAttachmentFiles', () {
    test('keeps every file the dialog returned', () async {
      final PickedAttachments picked = await pickAttachmentFiles(
        choose: () async => <XFile>[
          XFile('a.png'),
          XFile('b.mp4'),
          XFile('c.pdf'),
        ],
      );

      expect(
        picked.files.map((File file) => file.path),
        <String>['a.png', 'b.mp4', 'c.pdf'],
      );
      expect(picked.skipped, 0);
    });

    test('does not drop files on size — that is the planner\'s job', () async {
      // The picker used to stop the whole selection at the first oversized
      // file, discarding everything picked behind it before the planner could
      // skip it individually and report it.
      final PickedAttachments picked = await pickAttachmentFiles(
        choose: () async => <XFile>[
          XFile('tiny.png'),
          XFile('huge.mp4'),
          XFile('notes.pdf'),
        ],
      );

      expect(picked.files, hasLength(3));
      expect(picked.skipped, 0);
    });

    test('caps the count and says how many it left off', () async {
      const int offered = MailLimits.maxAttachmentCount + 3;
      final PickedAttachments picked = await pickAttachmentFiles(
        choose: () async =>
            <XFile>[for (int i = 0; i < offered; i++) XFile('file$i')],
      );

      expect(picked.files, hasLength(MailLimits.maxAttachmentCount));
      expect(picked.skipped, 3);
    });

    test('the cap is the message\'s, not this dialog\'s', () async {
      // Ten files three times used to be allowed: each dialog counted only its
      // own ten. With nine already attached there is room for one more.
      final PickedAttachments picked = await pickAttachmentFiles(
        choose: () async => <XFile>[XFile('a'), XFile('b'), XFile('c')],
        alreadyCount: MailLimits.maxAttachmentCount - 1,
      );

      expect(picked.files, hasLength(1));
      expect(picked.skipped, 2);
    });

    test('a full message takes nothing more', () async {
      final PickedAttachments picked = await pickAttachmentFiles(
        choose: () async => <XFile>[XFile('a')],
        alreadyCount: MailLimits.maxAttachmentCount,
      );

      expect(picked.files, isEmpty);
      expect(picked.skipped, 1);
    });

    test('an empty selection is not an error', () async {
      final PickedAttachments picked =
          await pickAttachmentFiles(choose: () async => <XFile>[]);

      expect(picked.files, isEmpty);
      expect(picked.skipped, 0);
    });
  });

  group('sanitizeFileName', () {
    test('does not split a surrogate pair at the filename cap', () {
      final String prefix = List<String>.filled(119, 'a').join();
      expect(sanitizeFileName('$prefix😀x'), prefix);
    });
  });


  group('nullable model copyWith fields', () {
    test('MessageSummary can explicitly clear an OTP', () {
      const MessageSummary original = MessageSummary(
        uid: 8, sequenceId: 8, subject: 'code', fromName: 'Name',
        fromEmail: 'n@example.com', date: null, isSeen: true, isFlagged: false, otp: '123456',
      );
      expect(original.copyWith().otp, '123456');
      expect(original.copyWith(otp: null).otp, isNull);
    });

    test('Contact can explicitly clear lastSeen', () {
      final DateTime seen = DateTime.utc(2026, 10, 23);
      final Contact original = Contact(email: 'someone@example.com', lastSeen: seen);
      expect(original.copyWith().lastSeen, seen);
      expect(original.copyWith(lastSeen: null).lastSeen, isNull);
    });
  });


  group('truncateUtf8BytesSafely', () {
    test('measures UTF-8 bytes and keeps multibyte characters whole', () {
      expect(truncateUtf8BytesSafely('a€b', 4), 'a€');
      expect(truncateUtf8BytesSafely('a€b', 3), 'a');
      expect(truncateUtf8BytesSafely('😀x', 3), '');
      expect(truncateUtf8BytesSafely('😀x', 4), '😀');
    });
  });
}
