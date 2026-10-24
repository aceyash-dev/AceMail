import 'dart:async';

import 'package:flutter/widgets.dart';

import 'translate.dart';

/// The app's own words, in the reader's language.
///
/// The hard part of translating an interface is not the translation, it is that
/// a `Text` cannot wait for one. A widget builds synchronously and an endpoint
/// answers asynchronously, so a string that has to be fetched at the moment it
/// is drawn is a string that flickers from English to something else.
///
/// So the strings a screen needs are fetched *before* it is built, once, and the
/// build reads them from a map. [Tr.load] does the fetching, [Tr.of] does the
/// reading, and a screen that has not loaded falls back to the words it was
/// written with — which is the right failure: a settings screen in English is a
/// settings screen, and a settings screen that will not draw is not.
///
/// What is translated is what the app *owns*: its own headings, labels and
/// explanations. Not the mail, which has its own Translate action, and not the
/// addresses and folder names, which are data rather than language.
abstract final class Tr {
  /// (language, english) -> translation, for the life of the process.
  ///
  /// In memory rather than on disk on purpose: a cached translation that
  /// outlives the process is a translation nobody can correct by asking again,
  /// and these are short strings on a screen somebody opens once.
  static final Map<String, String> _cache = <String, String>{};

  static String _key(String language, String english) => '$language\u0000$english';

  /// The translation of [english] into [language], or null if it is not known.
  ///
  /// Synchronous, because the caller is a build method.
  static String? of(String language, String english) {
    if (language.isEmpty || language == 'en') return english;
    return _cache[_key(language, english)];
  }

  /// Whether [language] needs translating at all.
  static bool needed(String language) => language.isNotEmpty && language != 'en';

  /// Fetches the translations this screen needs, and remembers them.
  ///
  /// Best effort and never throwing: a screen that cannot reach the endpoint
  /// draws in English, which is worse than being translated and much better than
  /// being blank. Returns how many it managed.
  static Future<int> load(
    Iterable<String> strings, {
    required String language,
    required String endpoint,
    String? apiKey,
  }) async {
    if (!needed(language)) return 0;

    final List<String> missing = <String>[
      for (final String s in strings)
        if (s.trim().isNotEmpty && !_cache.containsKey(_key(language, s))) s,
    ];
    if (missing.isEmpty) return 0;

    // One request per string rather than one for the lot: the endpoint takes a
    // single `q`, and joining them would need a separator that cannot appear in
    // a label — which is exactly the kind of assumption that breaks on the first
    // string with a newline in it.
    int done = 0;
    await Future.wait(<Future<void>>[
      for (final String english in missing)
        Translate.text(
          english,
          target: language,
          source: 'en',
          endpoint: endpoint,
          apiKey: apiKey,
        ).then((String translated) {
          _cache[_key(language, english)] = translated;
          done += 1;
        }).catchError((Object _) {
          // Left untranslated, and the screen falls back for this one string.
        }),
    ]);
    return done;
  }

  @visibleForTesting
  static void resetForTest() => _cache.clear();
}
