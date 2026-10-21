import 'dart:io';

import 'package:ace_mail/theme/astryx_theme.dart';
import 'package:ace_mail/theme/astryx_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the typeface', () {
    test('the app is set in Geograph, with Questrial behind it', () {
      expect(AstryxText.family, 'Geograph');
      expect(AstryxText.fallback, contains('Questrial'));

      final TextTheme text = buildAstryxTheme(Brightness.light).textTheme;
      expect(text.bodyMedium?.fontFamily, 'Geograph');
      // Geograph is a Latin face; a subject in another script has to have
      // somewhere to fall back to.
      expect(text.bodyMedium?.fontFamilyFallback, contains('Questrial'));
    });

    test('the font file is where pubspec says it is, and is a real font', () {
      // This is the check that catches a download that saved an HTML error page
      // under a .ttf name, which is exactly what a blocked fetch looks like.
      final File file = File('assets/fonts/Geograph.ttf');
      expect(file.existsSync(), isTrue, reason: 'assets/fonts/Geograph.ttf');

      final RandomAccessFile handle = file.openSync();
      final List<int> head = handle.readSync(4);
      handle.closeSync();
      // A TrueType file starts with 0x00010000.
      expect(head, <int>[0x00, 0x01, 0x00, 0x00]);
    });

    test('the fallback face is there too', () {
      expect(File('assets/fonts/Questrial-Regular.ttf').existsSync(), isTrue);
    });
  });
}
