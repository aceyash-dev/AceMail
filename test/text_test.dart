import 'package:ace_mail/util/text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('truncateSafely', () {
    test('leaves a short string alone', () {
      expect(truncateSafely('hello', 10), 'hello');
      expect(truncateSafely('hello', 5), 'hello');
    });

    test('cuts where asked, when nothing is in the way', () {
      expect(truncateSafely('hello world', 5), 'hello');
      expect(truncateSafely('hello world', 0), '');
      expect(truncateSafely('hello world', -3), '');
    });

    test('never cuts a character in half', () {
      // An emoji outside the basic plane is two UTF-16 code units, and half of
      // one renders as a replacement character — which is how a long message
      // ends up with a broken glyph at the end of the preview.
      const String waving = 'hi 👋 there';
      // The emoji starts at index 3 and occupies 3 and 4.
      expect(truncateSafely(waving, 4), 'hi ');
      expect(truncateSafely(waving, 5), 'hi 👋');
      expect(truncateSafely(waving, 6), 'hi 👋');
    });

    test('a string of nothing but a pair survives being cut at one', () {
      expect(truncateSafely('👋', 1), '');
      expect(truncateSafely('👋', 2), '👋');
    });

    test('the result is always valid UTF-16', () {
      const String mixed = 'a👋b𝄞c';
      for (int limit = 0; limit <= mixed.length + 2; limit++) {
        final String cut = truncateSafely(mixed, limit);
        // A lone surrogate anywhere in the result is the bug this exists to
        // prevent.
        for (int i = 0; i < cut.length; i++) {
          final int unit = cut.codeUnitAt(i);
          final bool loneHigh = unit >= 0xD800 && unit <= 0xDBFF &&
              (i + 1 >= cut.length ||
                  cut.codeUnitAt(i + 1) < 0xDC00 ||
                  cut.codeUnitAt(i + 1) > 0xDFFF);
          final bool loneLow = unit >= 0xDC00 && unit <= 0xDFFF &&
              (i == 0 ||
                  cut.codeUnitAt(i - 1) < 0xD800 ||
                  cut.codeUnitAt(i - 1) > 0xDBFF);
          expect(loneHigh || loneLow, isFalse,
              reason: 'lone surrogate at $i with limit $limit');
        }
      }
    });
  });
}
