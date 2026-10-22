import 'package:ace_mail/util/imap_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('uidExpungeUnavailableReason', () {
    test('allows per-message expunge when UIDPLUS is available', () {
      expect(
        uidExpungeUnavailableReason(supportsUidPlus: true),
        isNull,
      );
    });

    test('explains why deletion is refused without UIDPLUS', () {
      final String? reason =
          uidExpungeUnavailableReason(supportsUidPlus: false);
      expect(reason, isNotNull);
      expect(reason, contains('left this message unchanged'));
    });
  });
}
