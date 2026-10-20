import 'dart:math' as math;

import 'package:ace_mail/theme/astryx_theme.dart';
import 'package:ace_mail/theme/astryx_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio, 1:1 to 21:1.
double contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// AA for body text.
const double aa = 4.5;

/// AA for large text and non-text UI.
const double aaLarge = 3.0;

void main() {
  for (final Brightness brightness in Brightness.values) {
    final AstryxColors c = AstryxColors.fromScheme(
      buildAstryxScheme(brightness),
    );
    final String mode = brightness.name;

    group('$mode contrast', () {
      test('text on the accent passes AA', () {
        expect(
          contrast(c.onAccent, c.accent),
          greaterThanOrEqualTo(aa),
          reason: 'filled buttons, badges and toggles all sit on this',
        );
      });

      test('text on the muted accent passes AA', () {
        expect(
          contrast(c.onAccentMuted, c.accentMuted),
          greaterThanOrEqualTo(aa),
        );
      });

      test('body text on the page passes AAA', () {
        expect(
          contrast(c.textPrimary, c.backgroundBody),
          greaterThanOrEqualTo(7.0),
        );
      });

      test('secondary text — and therefore hints — passes AA', () {
        expect(
          contrast(c.textSecondary, c.backgroundBody),
          greaterThanOrEqualTo(aa),
        );
        expect(
          contrast(c.textSecondary, c.backgroundMuted),
          greaterThanOrEqualTo(aa),
          reason: 'the field fill is the muted surface',
        );
      });

      test('disabled ink is still legible as large text', () {
        expect(
          contrast(c.textDisabled, c.backgroundBody),
          greaterThanOrEqualTo(aaLarge),
        );
      });

      test('error text on its container passes AA', () {
        expect(
          contrast(c.errorMuted == c.error ? c.error : c.onErrorMuted, c.errorMuted),
          greaterThanOrEqualTo(aa),
        );
      });

      test('accent text passes AA on the page', () {
        // The fill role cannot do this job: the brand orange is 2.8:1 on Milk,
        // which is why there is a separate ink for accent-coloured text.
        expect(
          contrast(c.textAccent, c.backgroundBody),
          greaterThanOrEqualTo(aa),
        );
      });

      test('a filled accent is distinguishable from the page', () {
        expect(
          contrast(c.accent, c.backgroundBody),
          greaterThanOrEqualTo(aaLarge),
          reason: 'a filled button still has to read as a shape',
        );
      });
    });
  }
}
