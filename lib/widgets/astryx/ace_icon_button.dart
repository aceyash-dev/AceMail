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

enum AceIconButtonVariant { standard, filled, tonal, danger }

class AceIconButton extends StatelessWidget {
  const AceIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.variant = AceIconButtonVariant.standard,
    this.selected = false,
    this.size = AstryxSize.touchTarget,
    this.markBuilder,
  });

  final AceIcon icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final AceIconButtonVariant variant;
  final bool selected;
  final double size;

  /// Drawn instead of the glyph, and given the colour the button resolved for
  /// its foreground — so a mark can sit in a button and still invert when the
  /// button is selected, which a plain widget could not.
  final Widget Function(Color foreground)? markBuilder;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    final (Color background, Color foreground) = switch (variant) {
      // Selected fills with the accent itself and inverts the icon, rather than
      // tinting it: the hugeicons free set is stroke-only, so there is no filled
      // glyph to swap in, and a shape that fills is what says "this one is on"
      // in a set that has no other way to say it.
      AceIconButtonVariant.standard => (
          selected ? c.accent : Colors.transparent,
          selected ? c.onAccent : c.iconSecondary,
        ),
      AceIconButtonVariant.filled => (
          selected ? c.accent : c.surfaceHighest,
          selected ? c.onAccent : c.textPrimary,
        ),
      AceIconButtonVariant.tonal => (c.accentMuted, c.onAccentMuted),
      AceIconButtonVariant.danger => (c.errorMuted, c.onErrorMuted),
    };

    final Widget button = AceSpringy(
      enabled: onPressed != null,
      onTap: onPressed,
      semanticLabel: tooltip,
      builder: (BuildContext context, double press, bool hover) {
        final double t = acePressT(press);
        // A circular button tightens into a squircle as it is pressed — the
        // shape morph, at the smallest scale it happens in the app.
        final BorderRadius shape = BorderRadius.circular(
          lerpDouble(AstryxRadius.full, AstryxRadius.element, t)!,
        );
        return Transform.scale(
          // A press that does not move when motion is off, rather than one that
          // moves faster.
          scale: acePressScale(press, 0.06, respectReducedMotion: true),
          child: AnimatedContainer(
            // The fill arrives rather than appearing: at this size a hard cut
            // reads as a repaint, and the eye loses the button it just pressed.
            duration: AstryxMotion.of(AstryxMotion.fast),
            curve: AstryxMotion.emphasized,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: hover && background == Colors.transparent
                  ? c.overlayHover
                  : background,
              borderRadius: shape,
            ),
            // Tweened with the container, so the icon and the shape behind it
            // arrive together.
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: foreground),
              duration: AstryxMotion.of(AstryxMotion.fast),
              curve: AstryxMotion.emphasized,
              builder: (BuildContext context, Color? colour, Widget? child) {
                final Color drawn = colour ?? foreground;
                return markBuilder?.call(drawn) ??
                    // Selection arrives with a small movement. A state that
                    // changes without moving is a state you have to look for,
                    // and on the star it is the whole answer to "did that
                    // work". Subtle on purpose: this is every icon button in
                    // the app, not one of them.
                    AnimatedScale(
                      scale: selected ? 1.15 : 1.0,
                      duration: AstryxMotion.of(AstryxMotion.fast),
                      curve: AstryxMotion.emphasized,
                      child:
                          AceIconView(icon: icon, size: size * 0.5, color: drawn),
                    );
              },
            ),
          ),
        );
      },
    );

    return tooltip == null
        ? button
        : Tooltip(message: tooltip!, child: button);
  }
}

