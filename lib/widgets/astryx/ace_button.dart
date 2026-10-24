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
import 'ace_loader.dart';
import 'ace_springy.dart';

enum AceButtonVariant { primary, tonal, outlined, ghost, danger, success }

enum AceButtonSize { small, medium, large }

class AceButton extends StatelessWidget {
  const AceButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AceButtonVariant.ghost,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.size = AceButtonSize.medium,
  });

  final String label;
  final VoidCallback? onPressed;
  final AceButtonVariant variant;
  final AceIcon? icon;
  final bool expand;
  final bool loading;
  final AceButtonSize size;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    final (Color background, Color foreground, bool bordered) =
        switch (variant) {
      AceButtonVariant.primary => (c.accent, c.onAccent, false),
      AceButtonVariant.tonal => (
          c.secondaryContainer,
          c.onSecondaryContainer,
          false,
        ),
      AceButtonVariant.outlined => (Colors.transparent, c.textPrimary, true),
      AceButtonVariant.ghost => (Colors.transparent, c.textSecondary, false),
      AceButtonVariant.danger => (c.errorMuted, c.onErrorMuted, false),
      AceButtonVariant.success => (c.successMuted, c.success, false),
    };

    final double height = switch (size) {
      AceButtonSize.small => AstryxSize.elementMd,
      AceButtonSize.medium => AstryxSize.elementLg,
      AceButtonSize.large => AstryxSize.elementXl,
    };
    final double iconSize = size == AceButtonSize.large ? 21 : 18;

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (loading)
          Padding(
            padding: const EdgeInsets.only(right: AstryxSpace.s2),
            child: AceLoader(size: iconSize, color: foreground),
          )
        else if (icon != null) ...<Widget>[
          AceIconView(icon: icon!, size: iconSize, color: foreground),
          const SizedBox(width: AstryxSpace.s2),
        ],
        Text(
          label,
          style: AstryxText.bodyStrong(foreground),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final bool enabled = onPressed != null && !loading;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: AceSpringy(
        enabled: enabled,
        onTap: onPressed,
        builder: (BuildContext context, double press, bool hover) {
          // The shape morph: a stadium at rest, tightening toward a rounded
          // rectangle as it is pressed.
          final double t = acePressT(press);
          final BorderRadius shape = BorderRadius.circular(
            lerpDouble(AstryxRadius.full, AstryxRadius.lg, t)!,
          );
          final Color fill = hover && background == Colors.transparent
              ? c.overlayHover
              : background;

          return Transform.scale(
            scale: acePressScale(press, 0.045),
            child: Container(
              height: height,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(
                horizontal: size == AceButtonSize.small
                    ? AstryxSpace.s3
                    : AstryxSpace.s5,
              ),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: shape,
                border: bordered ? Border.all(color: c.borderEmphasized) : null,
              ),
              child: expand
                  ? SizedBox(width: double.infinity, child: content)
                  : content,
            ),
          );
        },
      ),
    );
  }
}

