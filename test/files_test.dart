import 'dart:io';

import 'package:ace_mail/data/limits.dart';
import 'package:ace_mail/util/files.dart';
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

    test('an empty selection is not an error', () async {
      final PickedAttachments picked =
          await pickAttachmentFiles(choose: () async => <XFile>[]);

      expect(picked.files, isEmpty);
      expect(picked.skipped, 0);
    });
  });
}
