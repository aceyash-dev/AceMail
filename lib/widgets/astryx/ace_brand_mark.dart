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

/// The Ace Mail mark: a postbox with its flag up and a letter at the front,
/// drawn as an outline on a Milk tile.
///
/// The flag is the one filled part, in the accent orange. Everything else is a
/// Milk fill with an ink outline — the accent means something because it is the
/// only thing wearing it. Same geometry as the launcher icon, at 108 units.
class AceBrandMark extends StatelessWidget {
  static const String assetPath = 'assets/brand/mark.png';
  const AceBrandMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    // The launcher's own foreground, so the mark in the app and the mark on the
    // home screen are the same drawing rather than two that resemble each other.
    return Image.asset(
      AceBrandMark.assetPath,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
  }
}

