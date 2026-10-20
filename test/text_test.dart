import 'package:ace_mail/util/text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('collapseBlankLines', () {
    test('leaves a single paragraph break alone', () {
      expect(collapseBlankLines('one\n\ntwo'), 'one\n\ntwo');
    });

    test('collapses whole screens of blank lines', () {
      expect(
        collapseBlankLines('one\n\n\n\n\n\ntwo'),
        'one\n\ntwo',
        reason: 'column-laid-out plain text arrives like this',
      );
    });

    test('collapses blank lines that carry spaces or tabs', () {
      expect(collapseBlankLines('one\n   \n\t\n\ntwo'), 'one\n\ntwo');
    });

    test('trims the leading and trailing whitespace of a body', () {
      expect(collapseBlankLines('\n\n\nhello\n\n\n'), 'hello');
    });

    test('leaves ordinary prose untouched', () {
      const String prose = 'Hi,\n\nThanks for the note.\n\nRegards';
      expect(collapseBlankLines(prose), prose);
    });

    test('handles an empty body', () {
      expect(collapseBlankLines(''), '');
    });
  });
}
