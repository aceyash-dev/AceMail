import 'package:ace_mail/services/backoff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Backoff', () {
    test('doubles from the base', () {
      expect(Backoff.delayFor(1), const Duration(milliseconds: 400));
      expect(Backoff.delayFor(2), const Duration(milliseconds: 800));
      expect(Backoff.delayFor(3), const Duration(milliseconds: 1600));
      expect(Backoff.delayFor(4), const Duration(milliseconds: 3200));
    });

    test('stops at the ceiling instead of growing forever', () {
      expect(Backoff.delayFor(20), Backoff.cap);
      expect(Backoff.delayFor(60), Backoff.cap);
    });

    test('an attempt below one is treated as the first', () {
      expect(Backoff.delayFor(0), Backoff.delayFor(1));
      expect(Backoff.delayFor(-5), Backoff.delayFor(1));
    });

    test('jitter only ever shortens, and by at most half', () {
      for (final double jitter in <double>[0, 0.25, 0.5, 1]) {
        final Duration delay = Backoff.delayFor(3, jitter: jitter);
        expect(delay, lessThanOrEqualTo(Backoff.delayFor(3)));
        expect(
          delay.inMilliseconds,
          greaterThanOrEqualTo(Backoff.delayFor(3).inMilliseconds ~/ 2),
        );
      }
    });

    test('a full jitter still backs off, rather than collapsing to nothing', () {
      expect(
        Backoff.delayFor(5, jitter: 1).inMilliseconds,
        greaterThan(Backoff.delayFor(1).inMilliseconds),
      );
    });

    test('jitter outside the range is clamped, not extrapolated', () {
      expect(Backoff.delayFor(2, jitter: -1), Backoff.delayFor(2, jitter: 0));
      expect(Backoff.delayFor(2, jitter: 5), Backoff.delayFor(2, jitter: 1));
    });

    test('gives up eventually', () {
      expect(Backoff.worthRetrying(1), isTrue);
      expect(Backoff.worthRetrying(4), isTrue);
      expect(Backoff.worthRetrying(5), isFalse);
      expect(Backoff.worthRetrying(9), isFalse);
    });
  });
}
