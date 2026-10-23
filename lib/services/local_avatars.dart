import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A picture somebody chose for an address, kept on this device.
///
/// **There is no way to set an avatar at a mail provider.** IMAP and SMTP have
/// no command for it, and none of the big providers exposes one to a client
/// that signs in with an app password. Gravatar is the only avatar standard
/// that mail clients agree on, and it is a separate service rather than a
/// provider feature — which is why the settings offer a link to it and why the
/// picture picked here is local.
///
/// Local wins over anything fetched, deliberately: a picture a person chose is
/// an answer, and a lookup is a guess. Somebody who uploads a photo and then
/// sees Gravatar's identicon anyway would be right to call it a bug.
///
/// Keyed by the MD5 of the lowercased address, which is the same key Gravatar
/// uses and the same one the avatar widget already computes. Nothing here is
/// secret — it is a picture of somebody, stored under a hash of an address that
/// is already on the device in plain text.
abstract final class LocalAvatars {
  static Directory? _directory;

  /// Resolved once at startup, because the widget that draws a row cannot wait
  /// for a future. Null until [init] runs, and a null directory means "no
  /// local pictures", which is a working app.
  static Directory? get _dir => _directory;

  /// address -> path, or an explicit null for "checked, there is none".
  static final Map<String, String?> _cache = <String, String?>{};

  /// Bumped whenever a picture is set or cleared.
  ///
  /// A picture changes in Settings and has to appear in the list behind it, on
  /// a row that was already built. The cache is static and the widgets are not
  /// listening to anything, so this is the thing they listen to.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static String keyFor(String email) =>
      md5.convert(utf8.encode(email.trim().toLowerCase())).toString();

  /// Called once, from startup. Best effort: a device that will not hand over a
  /// directory means the feature is off, not that the app fails to start.
  static Future<void> init() async {
    try {
      final Directory support = await getApplicationSupportDirectory();
      final Directory dir = Directory('${support.path}/avatars');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _directory = dir;
    } catch (_) {
      _directory = null;
    }
  }

  /// The picture for [email], or null.
  ///
  /// Synchronous on purpose — a stat, cached after the first call. A row that
  /// draws an avatar is not a place for a future, and there are forty of them.
  static String? pathFor(String email) {
    final String key = keyFor(email);
    if (_cache.containsKey(key)) return _cache[key];

    final Directory? dir = _dir;
    if (dir == null) return null;
    final File file = File('${dir.path}/$key');
    final String? path = file.existsSync() ? file.path : null;
    _cache[key] = path;
    return path;
  }

  /// Stores [source] as the picture for [email], replacing whatever was there.
  ///
  /// Copied rather than referenced: the picked file is often in a temporary
  /// directory the system is free to clear, and a picture that disappears
  /// overnight is worse than no picture.
  static Future<void> set(String email, File source) async {
    final Directory? dir = _dir;
    if (dir == null) throw const LocalAvatarException('No room to keep it.');
    if (!source.existsSync()) {
      throw const LocalAvatarException('That file could not be read.');
    }

    final String key = keyFor(email);
    final File target = File('${dir.path}/$key');
    try {
      await source.copy(target.path);
    } on FileSystemException {
      throw const LocalAvatarException('That file could not be read.');
    }
    _cache[key] = target.path;
    revision.value += 1;
  }

  /// Forgets the picture for [email], falling back to whatever is fetched.
  static Future<void> clear(String email) async {
    final String key = keyFor(email);
    final Directory? dir = _dir;
    _cache.remove(key);
    revision.value += 1;
    if (dir == null) return;
    final File file = File('${dir.path}/$key');
    if (file.existsSync()) {
      try {
        await file.delete();
      } on FileSystemException {
        // Nothing to do about it, and the cache entry is gone either way, so
        // the next lookup finds whatever is actually on disk.
      }
    }
  }

  /// Whether there is a picture of our own for [email].
  static bool has(String email) => pathFor(email) != null;

  @visibleForTesting
  static void resetForTest() {
    _cache.clear();
    _directory = null;
  }
}

/// A picture that could not be kept, in words worth showing somebody.
class LocalAvatarException implements Exception {
  const LocalAvatarException(this.message);

  final String message;

  @override
  String toString() => message;
}
