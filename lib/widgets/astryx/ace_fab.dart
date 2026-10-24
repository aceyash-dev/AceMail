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
import 'ace_springy.dart';

/// The expressive FAB: a pill that springs, and collapses to an icon when
/// there is not room for its label.
class AceFab extends StatelessWidget {
  const AceFab({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.extended = true,
  });

  final String label;
  final AceIcon icon;
  final VoidCallback? onPressed;

  /// Whether the label is showing. It shortens to a circle once the list has
  /// been scrolled — the label is there to teach the button, and by the time
  /// you have scrolled you have learned it.
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return AceSpringy(
      enabled: onPressed != null,
      onTap: onPressed,
      builder: (BuildContext context, double press, bool hover) {
        final double t = acePressT(press);
        final BorderRadius shape = BorderRadius.circular(
          lerpDouble(AstryxRadius.lg, AstryxRadius.full, t)!,
        );
        return Transform.scale(
          scale: acePressScale(press, 0.04),
          child: AnimatedContainer(
            duration: AstryxMotion.of(AstryxMotion.medium),
            curve: AstryxMotion.emphasized,
            height: AstryxSize.elementXl,
            padding: EdgeInsets.symmetric(
              horizontal: extended ? AstryxSpace.s5 : AstryxSpace.s4,
            ),
            decoration: BoxDecoration(
              // The accent itself, not a tint of it. This is the one button the
              // app is asking you to press, and a muted version of the accent
              // reads as a button that is not available.
              color: c.accent,
              borderRadius: shape,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AceIconView(icon: icon, size: 22, color: c.onAccent),
                // The label slides away rather than vanishing: a width change
                // with nothing in between reads as a glitch, and the eye
                // follows the word out.
                AnimatedSize(
                  duration: AstryxMotion.of(AstryxMotion.medium),
                  curve: AstryxMotion.emphasized,
                  alignment: Alignment.centerLeft,
                  child: extended
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const SizedBox(width: AstryxSpace.s3),
                            Text(
                              label,
                              style: AstryxText.bodyStrong(c.onAccent),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

