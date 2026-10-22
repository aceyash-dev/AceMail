import 'package:ace_mail/services/mail_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rule that keeps a removal from taking messages it was not asked to.
///
/// `UID EXPUNGE` (UIDPLUS, RFC 2359) removes exactly the UIDs given. Without
/// UIDPLUS the only expunge is mailbox-wide, and it takes every message
/// carrying `\Deleted` — including ones another client flagged and has not
/// finished with.
///
/// Checking the mailbox first narrows that window but cannot close it: another
/// client can flag a message between the check and the expunge. So the rule is
/// not "is the mailbox clear right now" but "can this server be trusted to take
/// only what it is given" — and the answer is UIDPLUS or nothing.
void main() {
  group('removalIsSafe', () {
    test('a server with UIDPLUS can remove one message at a time', () {
      expect(MailService.removalIsSafe(supportsUidPlus: true), isTrue);
    });

    test('a server without UIDPLUS cannot, whatever the mailbox holds', () {
      // The old rule asked whether any *other* message was flagged, and allowed
      // the mailbox-wide expunge when none was. That is a race, not a
      // guarantee, so the answer no longer depends on the mailbox.
      expect(MailService.removalIsSafe(supportsUidPlus: false), isFalse);
    });
  });
}
