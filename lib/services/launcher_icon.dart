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
/// The mark the launcher icon wears.
///
/// The suffix is what the Kotlin appends to an alias name, and the label is
/// what the setting calls it. They are kept together because a mark that is
/// named one thing in the picker and another in the manifest is a mark that
/// silently does nothing.
enum LauncherMark {
  envelope('', 'Envelope'),
  sealed('Sealed', 'Sealed'),
  letterA('A', 'A'),
  open('Open', 'Open envelope');

  const LauncherMark(this.suffix, this.label);

  final String suffix;
  final String label;
}

abstract final class LauncherIcon {
  static const MethodChannel _channel = MethodChannel('app.tab.mail/launcher');

  /// Points the launcher entry at [accent]'s icon, wearing [mark].
  ///
  /// The background is the accent, always: there is no setting for it, because
  /// an icon a different colour from the app it opens is not a choice anybody
  /// asked for. What is a choice is the mark.
  static Future<void> apply(
    AceAccent accent, {
    LauncherMark mark = LauncherMark.envelope,
  }) async {
    try {
      await _channel.invokeMethod<bool>('setLauncherAccent', <String, Object?>{
        'accent': accent.name,
        'mark': mark.suffix,
      });
    } catch (_) {
      // Not Android, or a build without the aliases. The icon keeps the colour
      // it had.
    }
  }
}
