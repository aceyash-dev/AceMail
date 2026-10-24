import 'dart:convert';

import 'package:http/http.dart' as http;

/// Translation, through a LibreTranslate endpoint.
///
/// LibreTranslate is a service, not a library: it is an HTTP endpoint that takes
/// text and returns it in another language. Which endpoint is a *setting* rather
/// than a constant, because there is no one instance — the project's own is rate
/// limited and asks for a key, and anybody can run their own. Hard-coding one
/// would mean the feature works for some people and quietly fails for the rest.
///
/// Nothing is sent until somebody asks for a translation. A mail client that
/// forwarded message bodies to a third party in the background would be doing
/// something its owner never agreed to, and the whole point of this app is that
/// it does not do that.
abstract final class Translate {
  /// The default endpoint: the project's own instance.
  static const String defaultEndpoint = 'https://libretranslate.com';

  /// The languages worth offering in a picker, as LibreTranslate names them.
  ///
  /// Not the full list — it is over forty entries, and a picker that long is a
  /// worse answer than a short one plus the ones this app's users are likely to
  /// want. The endpoint accepts any code it supports, so this is a convenience,
  /// not a limit: [isKnown] is what the settings use to say "we have not heard
  /// of that one" without refusing it.
  static const Map<String, String> languages = <String, String>{
    'en': 'English',
    'hi': 'Hindi',
    'bn': 'Bengali',
    'mr': 'Marathi',
    'ta': 'Tamil',
    'te': 'Telugu',
    'gu': 'Gujarati',
    'kn': 'Kannada',
    'ml': 'Malayalam',
    'pa': 'Punjabi',
    'ur': 'Urdu',
    'ar': 'Arabic',
    'zh': 'Chinese',
    'fr': 'French',
    'de': 'German',
    'es': 'Spanish',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'ja': 'Japanese',
    'ko': 'Korean',
  };

  static bool isKnown(String code) => languages.containsKey(code);

  static String nameFor(String code) => languages[code] ?? code;

  /// Translates [text] into [target].
  ///
  /// [source] is `auto` unless the caller knows better: the endpoint detects it,
  /// and a wrong guess costs a second round trip rather than a wrong answer.
  ///
  /// Throws [TranslateException] with something worth showing. The failures are
  /// separated because they need different answers from the person reading them:
  /// a bad endpoint is a setting to fix, a rate limit is a wait, and a language
  /// the endpoint does not have is a different choice.
  static Future<String> text(
    String text, {
    required String target,
    String source = 'auto',
    required String endpoint,
    String? apiKey,
  }) async {
    final String base = endpoint.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      throw const TranslateException(
        'No translation endpoint is set. Add one in Settings.',
      );
    }
    final Uri url = Uri.parse('$base/translate');
    if (!url.hasScheme) {
      throw const TranslateException(
        'That endpoint is not a web address. It should start with http:// or '
        'https://.',
      );
    }

    http.Response response;
    try {
      response = await http
          .post(
            url,
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, Object?>{
              'q': text,
              'source': source,
              'target': target,
              'format': 'text',
              if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (error) {
      throw const TranslateException(
        'The translation service could not be reached. Check the endpoint in '
        'Settings and this device\'s connection.',
      );
    }

    if (response.statusCode == 429) {
      throw const TranslateException(
        'The translation service is busy. Wait a moment and try again.',
      );
    }
    if (response.statusCode == 403 || response.statusCode == 401) {
      throw const TranslateException(
        'The translation service refused the request. It may need an API key.',
      );
    }
    if (response.statusCode >= 400) {
      throw TranslateException(_explain(response));
    }

    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const TranslateException('The service sent something unreadable.');
      }
      final Object? translated = decoded['translatedText'];
      if (translated is! String) {
        throw const TranslateException('The service sent no translation.');
      }
      return translated;
    } on FormatException {
      throw const TranslateException('The service sent something unreadable.');
    }
  }

  /// LibreTranslate says what went wrong in `error`, and it is usually worth
  /// passing on — it names the language it does not have, for instance.
  static String _explain(http.Response response) {
    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is String) {
        return 'The service said: ${decoded['error']}';
      }
    } catch (_) {
      // Fall through to the status code.
    }
    return 'The service refused the request (${response.statusCode}).';
  }
}

/// Something worth showing somebody, rather than a stack trace.
class TranslateException implements Exception {
  const TranslateException(this.message);

  final String message;

  @override
  String toString() => message;
}
