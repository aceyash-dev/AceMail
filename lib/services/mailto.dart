import 'package:flutter/services.dart';

/// A `mailto:` link the app was opened with.
///
/// Declaring the filter in the manifest is half of being an email client: the
/// other half is doing something with the address once the app is up. Without
/// this the app appears in the "Open with" sheet and then opens on the inbox,
/// having thrown away the thing somebody tapped.
class MailtoLink {
  const MailtoLink({required this.to, this.subject = '', this.body = ''});

  final String to;
  final String subject;
  final String body;
}

abstract final class Mailto {
  static const MethodChannel _channel = MethodChannel('app.tab.mail/intents');

  /// The link this launch was opened with, if any.
  ///
  /// Taken rather than listened for: the intent arrives before Flutter exists,
  /// and a link handled once must not reopen the composer every time the screen
  /// rebuilds. Null is the ordinary case — the app was opened from the launcher.
  static Future<MailtoLink?> take() async {
    String? raw;
    try {
      raw = await _channel.invokeMethod<String>('takeMailto');
    } catch (_) {
      // Not Android, or no handler: either way there is no link.
      return null;
    }
    return raw == null ? null : parse(raw);
  }

  /// Reads a `mailto:` URI. Kept separate so it can be tested without a device.
  static MailtoLink? parse(String raw) {
    final Uri? uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme.toLowerCase() != 'mailto') return null;

    // `mailto:a@b.com,c@d.com` puts the addresses in the path. Header
    // injection is the classic bug here — a subject carrying a newline can add
    // headers the sender never wrote — so anything with a control character is
    // dropped rather than passed through.
    final String to = Uri.decodeComponent(uri.path).trim();
    if (to.isEmpty) return null;

    String clean(String? value) {
      if (value == null) return '';
      return value.replaceAll(RegExp(r'[\r\n\x00]'), ' ').trim();
    }

    return MailtoLink(
      to: clean(to),
      subject: clean(uri.queryParameters['subject']),
      body: clean(uri.queryParameters['body']),
    );
  }
}
