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

/// A selectable pill chip.
class AceChip extends StatelessWidget {
  const AceChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final AceIcon? icon;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final Color foreground = selected ? c.onAccentMuted : c.textSecondary;

    return AceSpringy(
      enabled: onTap != null,
      onTap: onTap,
      builder: (BuildContext context, double press, bool hover) {
        final double t = acePressT(press);
        final BorderRadius shape = BorderRadius.circular(
          lerpDouble(AstryxRadius.full, AstryxRadius.container, t)!,
        );
        return Transform.scale(
          scale: acePressScale(press, 0.04),
          child: Container(
            height: AstryxSize.elementMd,
            padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s3),
            decoration: BoxDecoration(
              color: selected
                  ? c.accentMuted
                  : (hover ? c.surfaceHighest : c.backgroundMuted),
              borderRadius: shape,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  AceIconView(icon: icon!, size: 16, color: foreground),
                  const SizedBox(width: AstryxSpace.s1_5),
                ],
                Text(label, style: AstryxText.label(foreground)),
              ],
            ),
          ),
        );
      },
    );
  }
}

