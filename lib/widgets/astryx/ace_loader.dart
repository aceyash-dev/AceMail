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

/// The Material 3 Expressive loading indicator.
///
/// Expressive loading is not a spinner: it is one form that morphs through
/// Material's shape families, holding each briefly before moving on. The engine
/// lives in `shape_morph.dart`; this is the app-facing name for it.
///
/// It is deliberately not the envelope — at 18px inside a button there is no
/// room for a mark, and a morphing shape reads as "working" at any size.
class AceLoader extends StatelessWidget {
  const AceLoader({super.key, this.size = 40, this.color, this.progress});

  final double size;
  final Color? color;

  /// When set (0..1), the morph is scrubbed by that value instead of looping —
  /// which is how pull-to-refresh turns a drag into a shape change.
  final double? progress;

  @override
  Widget build(BuildContext context) => AceShapeMorph(
        size: size,
        color: color,
        progress: progress,
      );
}

