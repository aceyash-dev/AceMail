import 'dart:io';

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

  static bool get isDesktop =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  /// Whether the platform can blur what is behind a surface.
  ///
  /// Android 12 added `RenderEffect`, which is what a real backdrop blur needs;
  /// before that the only way to fake it is to read the pixels behind the
  /// widget, which is both slow and wrong the moment anything moves. iOS has had
  /// it since 13. Everywhere else the app draws a flat surface, which is what
  /// the desktop builds already did.
  static bool get supportsBlur => isIOS || (isAndroid && androidSdk >= 31);

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
