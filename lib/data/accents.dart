import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The fifteen accents the app offers.
///
/// Material's palette, one step in from the primaries so they sit next to Milk
/// without shouting. The default is the brand orange; everything else is a
/// choice, not a replacement.
///
/// Fifteen that are far enough apart to tell at a glance. Pink and rose were
/// both here, and a list where two entries look the same is a list where the
/// choice does not mean anything.
enum AceAccent {
  orange('Ace Orange', Color(0xFFF25C05)),
  red('Red', Color(0xFFE53935)),
  pink('Pink', Color(0xFFD81B60)),
  purple('Purple', Color(0xFF8E24AA)),
  indigo('Indigo', Color(0xFF3949AB)),
  blue('Blue', Color(0xFF1E88E5)),
  teal('Teal', Color(0xFF00897B)),
  green('Green', Color(0xFF2E7D32)),
  amber('Amber', Color(0xFFFFB300)),
  brown('Brown', Color(0xFF6D4C41)),
  cyan('Cyan', Color(0xFF00ACC1)),
  lime('Lime', Color(0xFF7CB342)),
  slate('Slate', Color(0xFF546E7A)),
  deepPurple('Deep purple', Color(0xFF5E35B1)),
  deepOrange('Deep orange', Color(0xFFE64A19));

  const AceAccent(this.label, this.seed);

  final String label;

  /// The colour itself. Used as the seed *and* pinned as `primary`, so the
  /// accent you pick is the accent you get — Material's tonal mapping would
  /// otherwise shift it.
  final Color seed;
}

/// Relative luminance, per WCAG.
double _luminance(Color colour) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(colour.r) +
      0.7152 * channel(colour.g) +
      0.0722 * channel(colour.b);
}

/// WCAG contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The ink to put on [background]: white or a warm near-black, whichever
/// actually reads.
///
/// An accent is a colour the user picks, so its contrast cannot be assumed. This
/// is why the palette does not hard-code an on-colour per accent: ten accents
/// times two modes is twenty numbers to get wrong, and this gets all twenty
/// right for any colour, including one added later.
/// The page colours the accents have to sit on. Kept here so the accent maths
/// does not depend on the theme, which is built *from* the accent.
const Color aceMilk = Color(0xFFFFFCF6);
const Color aceInk = Color(0xFF1A1614);

/// The accent, moved along its own lightness until it is usable.
///
/// An accent is the user's choice, so its contrast cannot be assumed. Blue at
/// full strength is 3.7:1 against white and 4.4:1 against ink — neither passes.
/// Amber at full strength is 1.75:1 against Milk, so a filled button would not
/// read as a shape. Rather than hard-code twenty fixes for ten accents, this
/// walks the colour towards the end of the scale that gives it room and stops
/// the moment it is legible.
///
/// The swatch in Settings still shows the accent as chosen; this is the fill.
Color readableAccent(Color seed, {required bool dark}) {
  final Color toward = dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  final Color page = dark ? aceInk : aceMilk;

  Color candidate = seed;
  for (int step = 0; step <= 30; step++) {
    final bool labelReads =
        contrastRatio(candidate, contrastingInk(candidate)) >= 4.5;
    // The accent is also used as a bare shape — the unread dot, the selected
    // row — so it has to be visible against the page on its own.
    final bool shapeReads = contrastRatio(candidate, page) >= 3.0;
    if (labelReads && shapeReads) return candidate;
    candidate = Color.lerp(candidate, toward, 0.05)!;
  }
  return candidate;
}

Color contrastingInk(Color background) {
  const Color white = Color(0xFFFFFFFF);
  const Color ink = Color(0xFF2A1E14);
  return contrastRatio(background, white) >= contrastRatio(background, ink)
      ? white
      : ink;
}
