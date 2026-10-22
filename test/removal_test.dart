import 'package:ace_mail/services/mail_errors.dart';
import 'package:ace_mail/util/removal.dart';
import 'package:flutter_test/flutter_test.dart';

/// The order of a removal, which is the whole of this bug.
///
/// The safety check used to run *inside* the expunge step, after the copy. A
/// refused move therefore had already put a copy in the target folder: the user
/// was told nothing had happened and was left with a duplicate. These tests
/// pin the order, so the check cannot drift back behind the copy.
void main() {
  group('removeMessage', () {
    test('a refusal copies nothing and flags nothing', () async {
      bool copied = false;
      bool flagged = false;

      await expectLater(
        removeMessage(
          canRemoveSafely: false,
          refusal: 'no',
          copy: () async => copied = true,
          flagAndExpunge: () async => flagged = true,
        ),
        throwsA(isA<MailRejectedException>()),
      );

      expect(copied, isFalse, reason: 'a refused move must not copy');
      expect(flagged, isFalse, reason: 'a refused move must not flag');
    });

    test('a refusal says why', () async {
      await expectLater(
        removeMessage(
          canRemoveSafely: false,
          refusal: 'This server cannot remove one message at a time.',
          copy: () async {},
          flagAndExpunge: () async {},
        ),
        throwsA(
          isA<MailRejectedException>().having(
            (MailRejectedException e) => e.toString(),
            'message',
            contains('one message at a time'),
          ),
        ),
      );
    });

    test('an allowed removal copies, then flags and expunges', () async {
      final List<String> steps = <String>[];

      await removeMessage(
        canRemoveSafely: true,
        refusal: 'no',
        copy: () async => steps.add('copy'),
        flagAndExpunge: () async => steps.add('flagAndExpunge'),
      );

      expect(steps, <String>['copy', 'flagAndExpunge']);
    });

    test('a failing copy does not flag or expunge', () async {
      bool flagged = false;

      await expectLater(
        removeMessage(
          canRemoveSafely: true,
          refusal: 'no',
          copy: () async => throw StateError('server said no'),
          flagAndExpunge: () async => flagged = true,
        ),
        throwsA(isA<StateError>()),
      );

      expect(flagged, isFalse);
    });
  });
}
