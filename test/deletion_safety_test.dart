import 'package:ace_mail/services/mail_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rule that keeps a delete from taking messages it was not asked to.
///
/// `UID EXPUNGE` (UIDPLUS) removes exactly the UIDs given. Without UIDPLUS the
/// only expunge is mailbox-wide, and it takes every message carrying
/// `\Deleted` — including ones another client flagged and has not finished
/// with. That is a data-loss path, so the decision is a pure function here and
/// asserted without a server.
void main() {
  group('expungeIsSafe', () {
    test('a server with UIDPLUS is always safe', () {
      expect(
        MailService.expungeIsSafe(
          supportsUidPlus: true,
          deletedUids: <int>{1, 2, 3},
          ourUids: <int>{2},
        ),
        isTrue,
      );
    });

    test('without UIDPLUS, it is safe when only ours is flagged', () {
      expect(
        MailService.expungeIsSafe(
          supportsUidPlus: false,
          deletedUids: <int>{7},
          ourUids: <int>{7},
        ),
        isTrue,
      );
    });

    test('without UIDPLUS, another app\'s pending deletion blocks it', () {
      // A mailbox-wide EXPUNGE would take message 9 as well as ours.
      expect(
        MailService.expungeIsSafe(
          supportsUidPlus: false,
          deletedUids: <int>{7, 9},
          ourUids: <int>{7},
        ),
        isFalse,
      );
    });

    test('without UIDPLUS, a mailbox with nothing flagged is safe', () {
      expect(
        MailService.expungeIsSafe(
          supportsUidPlus: false,
          deletedUids: <int>{},
          ourUids: <int>{7},
        ),
        isTrue,
      );
    });
  });
}
