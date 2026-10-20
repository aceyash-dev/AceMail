/// Exponential backoff, with a ceiling and jitter.
///
/// Pure and injectable: the jitter is passed in rather than generated here, so
/// the schedule can be asserted exactly in a test instead of approximated.
abstract final class Backoff {
  static const Duration base = Duration(milliseconds: 400);
  static const Duration cap = Duration(seconds: 30);

  /// The delay before attempt number [attempt] (1-based).
  ///
  /// Doubles each time from [base] until it reaches [cap], then stays there.
  /// [jitter] — a value in `[0, 1)` — spreads retries out so a fleet of clients
  /// does not reconnect in lockstep. At most half the delay is jitter, so the
  /// schedule still backs off rather than wobbling around a constant.
  static Duration delayFor(
    int attempt, {
    Duration base = base,
    Duration cap = cap,
    double jitter = 0,
  }) {
    if (attempt < 1) attempt = 1;

    final double capped = cap.inMilliseconds.toDouble();
    // Guard the shift: 1 << 40 is already far past any ceiling.
    final int shift = (attempt - 1).clamp(0, 30);
    final double raw = base.inMilliseconds.toDouble() * (1 << shift);
    final double bounded = raw < capped ? raw : capped;

    final double spread = (jitter.clamp(0.0, 1.0)) * bounded * 0.5;
    return Duration(milliseconds: (bounded - spread).round());
  }

  /// Whether it is still worth trying again, or the caller should give up and
  /// tell the user.
  static bool worthRetrying(int attempt, {int maxAttempts = 5}) =>
      attempt < maxAttempts;
}
