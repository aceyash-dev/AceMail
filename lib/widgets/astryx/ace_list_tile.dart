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

/// An expressive list row: springs on press, morphs its corners, and lifts to a
/// tonal surface when selected.
class AceListTile extends StatelessWidget {
  const AceListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return AceSpringy(
      enabled: onTap != null,
      onTap: onTap,
      builder: (BuildContext context, double press, bool hover) {
        final double t = acePressT(press);
        final BorderRadius shape = BorderRadius.circular(
          lerpDouble(AstryxRadius.container, AstryxRadius.inner, t)!,
        );
        return Transform.scale(
          scale: acePressScale(press, 0.02),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 1),
            padding: padding ??
                const EdgeInsets.symmetric(
                  horizontal: AstryxSpace.s3,
                  vertical: AstryxSpace.s3,
                ),
            decoration: BoxDecoration(
              color: selected
                  ? c.accentMuted
                  : (hover ? c.surfaceHighest : Colors.transparent),
              borderRadius: shape,
            ),
            child: Row(
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  leading!,
                  const SizedBox(width: AstryxSpace.s3),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: selected
                            ? AstryxText.bodyStrong(c.onAccentMuted)
                            : AstryxText.body(c.textPrimary),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AstryxSpace.s0_5),
                          child: Text(
                            subtitle!,
                            overflow: TextOverflow.ellipsis,
                            style: AstryxText.supporting(
                              selected ? c.onAccentMuted : c.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: AstryxSpace.s2),
                  trailing!,
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

