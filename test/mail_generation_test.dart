import 'package:ace_mail/models/mail_folder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether a cached page may be shown for a mailbox.
///
/// The rule this replaces was written as `cachedUnder != null && current != null
/// && cachedUnder == current`, which reads as "same generation" and behaves as
/// "drop the cache unless the server told us twice" — it would have quietly
/// removed the instant folder open for every server that does not report
/// UIDVALIDITY, which is most of them.
void main() {
  test('the same generation is the same generation', () {
    expect(sameMailboxGeneration(7, 7), isTrue);
    expect(sameMailboxGeneration(0, 0), isTrue);
  });

  test('a renumbered mailbox is not', () {
    expect(sameMailboxGeneration(7, 8), isFalse);
    expect(sameMailboxGeneration(8, 7), isFalse);
  });

  test('not knowing is not a reason to throw the cache away', () {
    // Fail-open, and this is the case that matters: a server that does not
    // report UIDVALIDITY is not evidence of a change.
    expect(sameMailboxGeneration(null, 7), isTrue);
    expect(sameMailboxGeneration(7, null), isTrue);
    expect(sameMailboxGeneration(null, null), isTrue);
  });
}
