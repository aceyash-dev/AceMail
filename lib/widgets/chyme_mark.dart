import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Chyme's mark, drawn rather than sampled.
///
/// The artwork was a 512px bitmap of a swoosh — dozens of concentric arcs
/// tapering into one another. At the sizes this actually appears at — 20px in a
/// settings row, 22px in the search bar — those arcs blur into a smudge, which
/// is what made the button impossible to name. A mark has to survive its
/// smallest use.
///
/// So it is drawn: a thick open ring with rounded ends, and a dot in the gap.
/// The ring is the C the old artwork was spelling; the dot is the thing being
/// said. Two strokes, no taper, legible at 16px and still clean at 64.
class ChymeMark extends StatelessWidget {
  const ChymeMark({super.key, this.size = 24, this.color});

  final double size;

  /// The colour to draw it in. Null uses the surrounding text colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color ink = color ?? IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ChymePainter(ink),
        // The mark is decoration beside a label that already says "Chyme";
        // announcing it twice is noise.
        isComplex: false,
      ),
    );
  }
}

class _ChymePainter extends CustomPainter {
  const _ChymePainter(this.ink);

  final Color ink;

  /// How far round the ring goes, in radians, and where it starts.
  ///
  /// A three-quarter ring, opened at the upper right so the gap and the dot
  /// read as one gesture: something said, trailing off.
  static const double _sweep = math.pi * 1.55;
  static const double _start = math.pi * 0.62;

  @override
  void paint(Canvas canvas, Size size) {
    final double side = math.min(size.width, size.height);
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final double stroke = side * 0.15;
    final double radius = (side - stroke) / 2;

    final Paint pen = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      _start,
      _sweep,
      false,
      pen,
    );

    // The dot sits where the ring stops, just outside it: the end of the
    // sentence rather than a hole in the shape.
    final double endAngle = _start + _sweep;
    final Offset dot = Offset(
      centre.dx + math.cos(endAngle) * radius,
      centre.dy + math.sin(endAngle) * radius,
    );
    canvas.drawCircle(
      dot,
      stroke * 0.62,
      Paint()
        ..color = ink
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_ChymePainter oldDelegate) => oldDelegate.ink != ink;
}
