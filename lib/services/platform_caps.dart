import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

/// What this device can actually do.
///
/// A setting that cannot work is worse than a missing one: it invites somebody
/// to change it, watches nothing happen, and leaves them thinking the app is
/// broken rather than that their phone is old. So the screens ask here and hide
/// what does not apply, instead of showing everything and hoping.
///
/// The answers are read once. None of them change while the app is running, and
/// several are asked on every build of a settings list.
abstract final class PlatformCaps {
  static final int androidSdk = _readAndroidSdk();

  static bool get isAndroid => Platform.isAndroid;

  static bool get isIOS => Platform.isIOS;

  static bool get isMacOS => Platform.isMacOS;

  static bool get isDesktop =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  /// Whether the platform can blur what is behind a surface.
  ///
  /// Everywhere Flutter can draw it. The previous answer was `iOS || macOS ||
  /// Android 12+`, on the reasoning that a real backdrop blur needs Android 12's
  /// `RenderEffect` — which is true of a *native* view and irrelevant here:
  /// Flutter's `ImageFilter.blur` is a shader in the engine's own render pass,
  /// and it has worked on every Android version Flutter supports. So the gate
  /// was wrong, and it was the whole reason the setting did nothing on most
  /// phones: the switch was on, the surfaces were built, and the capability said
  /// no.
  ///
  /// What is left is the one platform that genuinely cannot: the web renderer
  /// that has no shader pass.
  static bool get supportsBlur => !kIsWeb;

  /// Whether the launcher will re-tint a monochrome icon layer.
  ///
  /// Android 13. Below that the extra layer is ignored, so offering it would be
  /// offering a choice with no effect.
  static bool get supportsThemedIcon => isAndroid && androidSdk >= 33;

  /// Whether the system can animate a back gesture into the app's own motion.
  static bool get supportsPredictiveBack => isAndroid && androidSdk >= 34;

  /// Whether the app can ask for a fingerprint or a face.
  ///
  /// Asked of the platform rather than the hardware, because this is the cheap
  /// question: a device with a sensor but no enrolled finger still cannot
  /// unlock anything, and both answers arrive the same way.
  static bool get supportsBiometrics => isAndroid || isIOS;

  static int _readAndroidSdk() {
    if (!Platform.isAndroid) return 0;
    // "Android 14 (SDK 34)". The version name is a moving target; the number is
    // not, and it is the number every capability is keyed to.
    final RegExpMatch? match =
        RegExp(r'API (\d+)').firstMatch(Platform.operatingSystemVersion);
    return match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
  }
}
