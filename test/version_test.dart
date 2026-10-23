import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The version in `pubspec.yaml`, and the Android version code it becomes.
///
/// Flutter reads `version: x.y.z+N` and passes N to Gradle as `versionCode`.
/// Without the `+N` it passes **1** — so `0.5.1`, which had no build number,
/// shipped with version code 1, and Android refused to install it over any
/// earlier build: "App not installed." That is a release that cannot reach
/// anybody, and nothing in the build complains, so it is checked here.
void main() {
  test('the version carries a build number, which is the Android version code',
      () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final RegExpMatch? match =
        RegExp(r'^version:\s*(\S+)\s*$', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml has no version line');

    final String version = match!.group(1)!;
    expect(
      version,
      matches(RegExp(r'^\d+\.\d+\.\d+\+\d+$')),
      reason: 'version "$version" has no +build number. Flutter turns that into '
          'version code 1, which is a downgrade from every build before it and '
          'Android will refuse to install it.',
    );

    final int code = int.parse(version.split('+').last);
    expect(code, greaterThan(0));
  });
}
