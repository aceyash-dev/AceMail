// ignore_for_file: unused_import
// Part of the AceMail Astryx design system.
import 'dart:async';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../../theme/ace_icons.dart';
import '../../theme/astryx_theme.dart';
import '../../theme/astryx_tokens.dart';
import '../../util/haptics.dart';
import '../shape_morph.dart';
import '../ace_icon_view.dart';
import 'ace_press_helpers.dart';

/// A padded, rounded surface — Astryx's container role, on the tonal ramp.
class AceSurface extends StatelessWidget {
  const AceSurface({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.border = true,
    this.radius = AstryxRadius.container,
    this.squircle = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final bool border;
  final double radius;

  /// Continuous corners, for the large surfaces expressive M3 softens.
  final bool squircle;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final Decoration decoration = BoxDecoration(
      color: color ?? c.backgroundSurface,
      borderRadius: squircle ? null : BorderRadius.circular(radius),
      border: border ? Border.all(color: c.border) : null,
    );

    if (!squircle) {
      // Clipped, so a child with its own rounded background — a selected row in
      // a group, say — cannot spill past the card's corners.
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(padding: padding, decoration: decoration, child: child),
      );
    }

    return ClipPath(
      clipper: const AceSquircleClipper(),
      child: CustomPaint(
        painter: _SquircleSurface(
          color: color ?? c.backgroundSurface,
          border: border ? c.border : null,
        ),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}

/// Clips to a continuous corner. Shared by every surface that wants the shape.
class AceSquircleClipper extends CustomClipper<Path> {
  const AceSquircleClipper({this.exponent = 4});

  final double exponent;

  @override
  Path getClip(Size size) =>
      AstryxShape.squircle(Offset.zero & size, exponent: exponent);

  @override
  bool shouldReclip(covariant AceSquircleClipper oldClipper) =>
      oldClipper.exponent != exponent;
}

class _SquircleSurface extends CustomPainter {
  const _SquircleSurface({required this.color, required this.border});

  final Color color;
  final Color? border;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawPath(
      AstryxShape.squircle(rect),
      Paint()..color = color,
    );
    if (border != null) {
      // Inset by a full pixel so the clip does not shave the stroke.
      canvas.drawPath(
        AstryxShape.squircle(rect.deflate(1)),
        Paint()
          ..color = border!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SquircleSurface old) =>
      old.color != color || old.border != border;
}

