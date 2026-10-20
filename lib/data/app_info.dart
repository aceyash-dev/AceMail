import 'package:package_info_plus/package_info_plus.dart';

/// The installed app's version, read from the platform.
///
/// Deliberately not a constant: a version typed into the source drifts from
/// `pubspec.yaml` the first time either one changes, and the About screen then
/// confidently reports something that is not installed.
abstract final class AppInfo {
  static String version = '';
  static String build = '';

  static Future<void> load() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      version = info.version;
      build = info.buildNumber;
    } catch (_) {
      // Nothing readable; the label below degrades rather than lying.
      version = '';
      build = '';
    }
  }

  /// `0.3.3 (7)`, or empty if the platform would not say.
  static String get label {
    if (version.isEmpty) return '';
    return build.isEmpty ? version : '$version ($build)';
  }
}
