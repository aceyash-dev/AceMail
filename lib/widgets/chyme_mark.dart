import 'package:flutter/material.dart';

/// Chyme's mark.
///
/// The artwork is a white mark with transparency — extracted from the logo, so
/// the strokes carry their own anti-aliasing and the field behind them is
/// nothing. That is what lets one file sit on the accent in the sheet's header
/// and in plain ink in a settings row: it is a mask, and it takes whatever
/// colour it is given.
class ChymeMark extends StatelessWidget {
  const ChymeMark({super.key, this.size = 24, this.color});

  /// The size asked for, before the optical correction below.
  final double size;

  /// The colour to draw it in. Null draws the artwork as it is — white.
  final Color? color;

  /// The artwork is full-bleed — the mark fills almost the whole file — where a
  /// Hugeicon fills about 85% of its box. Drawn at the same nominal size the
  /// mark therefore reads a fifth larger than the stroke icons it sits beside,
  /// which is what "the Chyme mark is the wrong size" turned out to be. This is
  /// the same correction [AceIconView] applies, so a given size now means the
  /// same thing for both.
  static const double opticalScale = 0.85;

  @override
  Widget build(BuildContext context) {
    final double drawn = size * opticalScale;
    return Image.asset(
      'assets/brand/chyme.png',
      width: drawn,
      height: drawn,
      // srcIn, not a tint: a tint would blend the white into the colour and
      // leave the mark milky. srcIn replaces every opaque pixel with the
      // colour and leaves the alpha alone.
      color: color,
      colorBlendMode: color == null ? null : BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
  }
}
