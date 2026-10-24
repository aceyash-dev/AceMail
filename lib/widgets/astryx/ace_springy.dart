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

/// A press that springs, and a shape that morphs while it does.
///
/// This is the interaction primitive Material 3 Expressive is built around:
/// motion comes from a spring rather than a curve, so a press settles with a
/// little life instead of easing flatly. The builder is handed the current
/// press (0 resting, 1 fully pressed, and briefly outside that range on the
/// rebound) and the hover state, so each component can morph its own shape.
class AceSpringy extends StatefulWidget {
  const AceSpringy({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.semanticLabel,
  });

  final Widget Function(BuildContext context, double press, bool hover) builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;

  /// The name a screen reader announces, for a control whose visible content is
  /// only an icon.
  final String? semanticLabel;

  @override
  State<AceSpringy> createState() => _AceSpringyState();
}

class _AceSpringyState extends State<AceSpringy>
    with SingleTickerProviderStateMixin {
  /// Unbounded so the spring can overshoot past its target — that overshoot is
  /// the point.
  late final AnimationController _press =
      AnimationController.unbounded(vsync: this, value: 0);

  bool _hover = false;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _springTo(double target) {
    _press.animateWith(
      SpringSimulation(
        // Pressing is a spatial move and uses the snappy spring; releasing uses
        // the livelier one so the rebound is visible.
        target > _press.value
            ? AstryxMotion.spatialFast
            : AstryxMotion.press,
        _press.value,
        target,
        _press.velocity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool live = widget.enabled && widget.onTap != null;

    return Semantics(
      // A tap target is a button to a screen reader, whichever component it is
      // — and it stays a button when disabled, just not an enabled one. The
      // label goes on this same node, or the role and the name end up as
      // siblings and neither is announced properly.
      button: true,
      enabled: live,
      label: widget.semanticLabel,
      child: MouseRegion(
      cursor: live ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: live ? (_) => _springTo(1) : null,
        onTapUp: live ? (_) => _springTo(0) : null,
        onTapCancel: live ? () => _springTo(0) : null,
        onTap: live ? widget.onTap : null,
        onLongPress: live ? widget.onLongPress : null,
        child: AnimatedBuilder(
          animation: _press,
          builder: (BuildContext context, _) =>
              widget.builder(context, _press.value, _hover),
        ),
      ),
      ),
    );
  }
}

