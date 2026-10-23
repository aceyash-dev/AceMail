import 'dart:math' as math;

import 'package:ace_mail/data/accents.dart';
import 'package:ace_mail/theme/astryx_theme.dart';
import 'package:ace_mail/theme/astryx_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color colour) {
  double channel(double value) {
    final double v = value / 255;
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel((colour.r * 255).roundToDouble()) +
      0.7152 * channel((colour.g * 255).roundToDouble()) +
      0.0722 * channel((colour.b * 255).roundToDouble());
}

/// The contrast ratio between two colours, 1 to 21.
double contrast(Color a, Color b) {
  final double x = _luminance(a);
  final double y = _luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  /// Every surface a text role can end up on.
  List<({String name, Color colour})> surfaces(AstryxColors c) =>
      <({String name, Color colour})>[
        (name: 'backgroundBody', colour: c.backgroundBody),
        (name: 'backgroundSurface', colour: c.backgroundSurface),
        (name: 'backgroundCard', colour: c.backgroundCard),
        (name: 'backgroundMuted', colour: c.backgroundMuted),
        (name: 'surfaceHighest', colour: c.surfaceHighest),
      ];

  group('text clears AA', () {
    for (final Brightness brightness in Brightness.values) {
      for (final AceAccent accent in AceAccent.values) {
        test('${brightness.name} · ${accent.name}', () {
          final ThemeData theme = buildAstryxTheme(brightness, accent: accent);
          final AstryxColors c = theme.extension<AstryxColors>()!;

          for (final ({String name, Color colour}) surface in surfaces(c)) {
            // 4.5:1 is AA for body text. Body and supporting text are the two
            // roles that carry sentences.
            expect(
              contrast(c.textPrimary, surface.colour),
              greaterThanOrEqualTo(4.5),
              reason: 'textPrimary on ${surface.name} (${brightness.name}, '
                  '${accent.name})',
            );
            expect(
              contrast(c.textSecondary, surface.colour),
              greaterThanOrEqualTo(4.5),
              reason: 'textSecondary on ${surface.name} (${brightness.name}, '
                  '${accent.name})',
            );
          }

          // The accent as *text* — links, the "Look around first" button — is
          // held to the same bar as any other text.
          for (final ({String name, Color colour}) surface in surfaces(c)) {
            expect(
              contrast(c.textAccent, surface.colour),
              greaterThanOrEqualTo(4.5),
              reason: 'textAccent on ${surface.name} (${brightness.name}, '
                  '${accent.name})',
            );
          }

          // A label on the accent fill: the compose button, the selected tab,
          // the current folder.
          expect(
            contrast(c.onAccent, c.accent),
            greaterThanOrEqualTo(4.5),
            reason: 'onAccent on accent (${brightness.name}, ${accent.name})',
          );

          // The error line, and the success and warning ones, are read as text.
          expect(
            contrast(c.error, c.backgroundBody),
            greaterThanOrEqualTo(4.5),
            reason: 'error on backgroundBody (${brightness.name}, '
                '${accent.name})',
          );
        });
      }
    }
  });

  group('components clear 3:1', () {
    // Non-text: an icon, a border, the accent as a fill. WCAG asks 3:1 of these,
    // and the app's own rule is that a shape must read against the page.
    for (final Brightness brightness in Brightness.values) {
      for (final AceAccent accent in AceAccent.values) {
        test('${brightness.name} · ${accent.name}', () {
          final ThemeData theme = buildAstryxTheme(brightness, accent: accent);
          final AstryxColors c = theme.extension<AstryxColors>()!;

          expect(
            contrast(c.iconSecondary, c.backgroundBody),
            greaterThanOrEqualTo(3),
            reason: 'iconSecondary (${brightness.name}, ${accent.name})',
          );
          expect(
            contrast(c.accent, c.backgroundBody),
            greaterThanOrEqualTo(3),
            reason: 'accent as a fill (${brightness.name}, ${accent.name})',
          );
          expect(
            contrast(c.border, c.backgroundBody),
            greaterThanOrEqualTo(1.2),
            reason: 'border is a hairline, not a shape '
                '(${brightness.name}, ${accent.name})',
          );
        });
      }
    }
  });
}
