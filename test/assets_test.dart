import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Flutter bundles only what the pubspec declares, and an undeclared asset
/// fails at runtime rather than at build time — so the app ships, the mark
/// renders as nothing, and nobody finds out until someone looks. This is the
/// test that would have caught 0.5.0.
void main() {
  test('every asset the code refers to is declared and exists', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();

    final RegExp declared = RegExp(r'^\s+- (assets/[^\s]+)', multiLine: true);
    final List<String> declaredPaths = declared
        .allMatches(pubspec)
        .map((RegExpMatch m) => m.group(1)!)
        .toList();

    expect(
      declaredPaths,
      isNotEmpty,
      reason: 'the pubspec declares no assets at all',
    );

    // Every directory declared must exist and have something in it.
    for (final String path in declaredPaths) {
      if (path.endsWith('/')) {
        final Directory dir = Directory(path);
        expect(dir.existsSync(), isTrue, reason: '$path is declared but missing');
        expect(
          dir.listSync().whereType<File>(),
          isNotEmpty,
          reason: '$path is declared but empty',
        );
      } else {
        expect(File(path).existsSync(), isTrue,
            reason: '$path is declared but missing');
      }
    }

    // And every asset path named in the code must be covered by a declaration.
    final List<String> referenced = <String>[];
    for (final FileSystemEntity entity
        in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final RegExp ref = RegExp("'(assets/[^']+)'");
      for (final RegExpMatch m in ref.allMatches(entity.readAsStringSync())) {
        referenced.add(m.group(1)!);
      }
    }

    expect(referenced, isNotEmpty, reason: 'no asset paths found in lib/');

    for (final String ref in referenced.toSet()) {
      final bool covered = declaredPaths.any((String d) =>
          d.endsWith('/') ? ref.startsWith(d) : ref == d);
      expect(covered, isTrue, reason: '$ref is used but not declared');
      expect(File(ref).existsSync(), isTrue, reason: '$ref does not exist');
    }
  });
}
