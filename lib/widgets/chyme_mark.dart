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

  final double size;

  /// The colour to draw it in. Null draws the artwork as it is — white.
  final Color? color;

  /// How much of the box the mark actually draws in.
  ///
  /// The artwork fills 95% of its own canvas, where the icon set leaves about a
  /// quarter of its box empty. So a mark given the same `size` as an icon beside
  /// it reads as a size larger — which is what it was doing.
  static const double _fill = 0.8;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/chyme.png',
      width: size * _fill,
      height: size * _fill,
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
