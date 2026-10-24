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
import 'ace_avatar_tone.dart';

/// A sender's initials on a tonal tile, used wherever there is no picture.
class AceInitialsAvatar extends StatelessWidget {
  const AceInitialsAvatar({
    super.key,
    required this.initials,
    this.size = 40,
    this.tone,
    this.seed,
  });

  final String initials;
  final double size;
  final Color? tone;

  /// What the tone is derived from — usually the address, so one sender keeps
  /// one colour across the app.
  final String? seed;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final Color background = tone ?? aceAvatarTone(seed ?? initials, c);

    return CustomPaint(
      painter: _AvatarTile(color: background),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            initials,
            style: AstryxText.bodyStrong(c.onAccentMuted).copyWith(
              fontSize: size * 0.36,
              color: c.onAccentMuted,
            ),
          ),
        ),
      ),
    );
  }

}

class _AvatarTile extends CustomPainter {
  const _AvatarTile({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      AstryxShape.squircle(Offset.zero & size),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarTile old) => old.color != color;
}

