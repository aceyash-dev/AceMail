import 'package:flutter/services.dart';

import '../data/accents.dart';

/// The launcher icon, which wears the accent.
///
/// Android fixes a launcher icon at install time, so the app ships fifteen of
/// them — one per accent, as activity aliases — and points the launcher at the
/// one matching the setting. The switching itself is in `MainActivity.kt`,
/// because `PackageManager` is not something Dart can reach; this is the call.
///
/// Best effort, everywhere. A platform without aliases, a launcher that ignores
/// the change, a channel that is not there: the icon stays as it was and nothing
/// else in the app is affected. An icon is the least important thing here and
/// must never be the reason something fails.
abstract final class LauncherIcon {
  static const MethodChannel _channel = MethodChannel('app.tab.mail/launcher');

  /// Points the launcher entry at [background]'s icon, wearing [monogram]'s mark.
  ///
  /// Two marks, one set of backgrounds: the switch changes the foreground layer
  /// and nothing else, which is what makes the two icons the same app rather
  /// than two designs.
  static Future<void> apply(AceAccent background, {bool monogram = false}) async {
    try {
      await _channel.invokeMethod<bool>('setLauncherAccent', <String, Object?>{
        'accent': background.name,
        'monogram': monogram,
      });
    } catch (_) {
      // Not Android, or a build without the aliases. The icon keeps the colour
      // it had.
    }
  }
}
