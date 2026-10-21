/// Finds one-time codes in a message so they can be shown in the list, without
/// opening the mail — which is the whole point of an OTP.
///
/// The rule is deliberately conservative. A bare 4-to-8 digit number is not a
/// code: it is an order number, a house number, a price, a year. A number only
/// counts when the words around it say what it is.
abstract final class OtpDetector {
  /// 4–8 digits, on their own. `\b` on both sides keeps it from carving a
  /// code out of a longer number such as a card or a phone number.
  static final RegExp _code = RegExp(r'\b(\d{4,8})\b');

  /// The words that turn a number into a code.
  static final RegExp _context = RegExp(
    r'otp|one[\s_-]?time|verification|verify|passcode|pass[\s_-]?code|'
    r'security code|access code|sign[\s_-]?in code|login code|'
    r'confirmation code|auth(?:entication)? code|2fa|two[\s_-]?factor|'
    r'code is|code:|code -',
    caseSensitive: false,
  );

  /// How far either side of a number the context may sit.
  static const int _window = 64;

  /// Whether a subject suggests a code is inside at all — used to decide
  /// whether fetching a body preview is worth it.
  static bool looksLikeCodeMail(String subject) => _context.hasMatch(subject);

  /// The code in [text], or null when there is not one worth showing.
  ///
  /// When more than one number has context near it — "Order 998877 shipped.
  /// Your OTP is 445566" — the one *closest* to the words wins, because those
  /// words are describing it.
  static String? find(String text) {
    if (text.isEmpty) return null;

    String? best;
    int bestDistance = 1 << 30;

    for (final RegExpMatch match in _code.allMatches(text)) {
      final String digits = match.group(1)!;
      if (!_plausible(digits)) continue;

      final int distance = _contextDistance(text, match);
      if (distance < 0 || distance >= bestDistance) continue;
      bestDistance = distance;
      best = digits;
    }
    return best;
  }

  /// How many characters separate the nearest context word from [match], or -1
  /// when there is none within the window.
  static int _contextDistance(String text, RegExpMatch match) {
    final int from = (match.start - _window).clamp(0, text.length);
    final int to = (match.end + _window).clamp(0, text.length);

    int best = -1;
    for (final RegExpMatch context in _context.allMatches(text.substring(from, to))) {
      final int start = from + context.start;
      final int end = from + context.end;
      final int distance = end <= match.start
          ? match.start - end
          : (start >= match.end ? start - match.end : 0);
      if (best < 0 || distance < best) best = distance;
    }
    return best;
  }

  /// Four-digit numbers that are almost never codes.
  static bool _plausible(String digits) {
    if (digits.length != 4) return true;
    final int value = int.parse(digits);
    // A year, or a round number.
    if (value >= 1900 && value <= 2100) return false;
    if (digits == '0000' || digits == '1234') return false;
    return true;
  }

  /// Codes from a raw message body, which is usually quoted-printable: soft
  /// line breaks are removed first, or a code split across two lines is lost.
  static String? findInBody(String raw) {
    if (raw.isEmpty) return null;
    final String joined = raw
        .replaceAll(RegExp(r'=\r?\n'), '')
        .replaceAll(RegExp(r'<[^>]*>'), ' ');
    return find(joined);
  }
}
