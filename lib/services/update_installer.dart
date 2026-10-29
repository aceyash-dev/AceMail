import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../util/redact.dart';
import 'update_check.dart';

/// Downloading a release, and handing it to the system installer.
///
/// Android has no silent install for an app that was not installed from the
/// store, and that is a good rule: an app that can replace itself without asking
/// is an app that can be made to replace itself. So this does the two things it
/// is allowed to — fetch the file, and ask the system to install it — and the
/// system shows its own "allow this source" screen the first time, which is the
/// permission being asked for.
///
/// Everything is best effort. A download that fails says so and leaves nothing
/// behind; a file already downloaded is reused rather than fetched again.
abstract final class UpdateInstaller {
  /// Where a downloaded release waits. The cache directory, because it is the
  /// one place the app may write that the installer can read, and because the
  /// system may clear it.
  static Future<Directory> _cache() async {
    final Directory base = await getTemporaryDirectory();
    final Directory dir = Directory('${base.path}/updates');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _fileName(UpdateRelease release) =>
      'AceMail-${release.version}-${release.apkUrl?.split('/').last ?? 'app.apk'}';

  /// The file for [release] if it has already been downloaded.
  static Future<File?> downloaded(UpdateRelease release) async {
    if (release.apkUrl == null) return null;
    try {
      final File file = File('${(await _cache()).path}/${_fileName(release)}');
      if (!await file.exists()) return null;
      if (await file.length() < 1024 * 1024) {
        // A truncated download is worse than none: the installer would open it
        // and fail with a parse error that says nothing about what happened.
        await file.delete();
        return null;
      }
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Fetches the APK, reporting progress from 0 to 1.
  ///
  /// Null when this release has no APK, or when the platform cannot install one
  /// — in which case the caller offers the release page instead.
  static Future<File?> download(
    UpdateRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    final String? url = release.apkUrl;
    if (url == null) return null;

    final File? already = await downloaded(release);
    if (already != null) {
      onProgress?.call(1);
      return already;
    }

    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    File? part;
    try {
      final HttpClientRequest request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'AceMail');
      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final Directory dir = await _cache();
      final File file = File('${dir.path}/${_fileName(release)}');
      part = File('${file.path}.part');
      final IOSink sink = part.openWrite();

      final int total = response.contentLength;
      int received = 0;
      await for (final List<int> chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
      await sink.close();

      // Renamed only once it is whole, so a download interrupted half way is
      // never mistaken for a finished one.
      await part.rename(file.path);
      onProgress?.call(1);
      return file;
    } catch (error) {
      debugPrint('Ace Mail: update download failed (${Redact.safe(error)})');
      try {
        if (part != null && await part.exists()) await part.delete();
      } catch (_) {
        // Nothing to clean up.
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Asks the system to install [file].
  ///
  /// Returns false when nothing was launched. On Android the first call for a
  /// sideloaded app opens the "allow installs from this source" screen instead
  /// of the installer, which is the permission being asked for — the person
  /// grants it, comes back, and taps again.
  static Future<bool> install(File file) async {
    if (!Platform.isAndroid) return false;
    try {
      final OpenFileResult result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done) {
        debugPrint('Ace Mail: installer said ${result.type}: ${result.message}');
        return false;
      }
      return true;
    } catch (error) {
      debugPrint('Ace Mail: could not start the installer '
          '(${Redact.safe(error)})');
      return false;
    }
  }

  /// Whether this platform can install a downloaded APK at all.
  static bool get canInstall => !kIsWeb && Platform.isAndroid;
}
