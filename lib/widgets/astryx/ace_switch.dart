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

/// A switch in the shape Material 3 Expressive gives it: a pill, and a thumb
/// that carries a tick when it is on and a cross when it is off.
///
/// The mark is the point. A switch's position says which way it is set, but
/// position is a thing you have to read; a tick is a thing you recognise. It
/// also means the state survives being glanced at rather than looked at.
class AceSwitch extends StatefulWidget {
  const AceSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<AceSwitch> createState() => _AceSwitchState();
}

class _AceSwitchState extends State<AceSwitch>
    with SingleTickerProviderStateMixin {
  /// Drives the thumb, so the movement can overshoot.
  ///
  /// An `AnimatedAlign` gets the thumb there and stops dead. Material 3
  /// Expressive does not: the thumb carries momentum, arrives, and settles —
  /// and a switch that settles reads as a physical thing rather than as a
  /// picture of one.
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: AstryxMotion.of(const Duration(milliseconds: 320)),
    value: widget.value ? 1 : 0,
  );

  @override
  void didUpdateWidget(AceSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    if (widget.value) {
      _slide.forward();
    } else {
      _slide.reverse();
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  void _toggle() {
    final ValueChanged<bool>? changed = widget.onChanged;
    if (changed == null) return;
    // A switch is the smallest decision in the app and the one people flip most
    // often, so it is the one that most needs to feel like it was touched.
    unawaited(AceHaptics.select());
    changed(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final bool enabled = widget.onChanged != null;
    final bool value = widget.value;

    const double trackWidth = 52;
    const double trackHeight = 32;
    const double inset = 4;
    final double thumb = trackHeight - inset * 2;

    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _toggle : null,
        child: AnimatedContainer(
          duration: AstryxMotion.of(const Duration(milliseconds: 260)),
          curve: AstryxMotion.emphasized,
          width: trackWidth,
          height: trackHeight,
          decoration: BoxDecoration(
            color: value
                ? (enabled ? c.accent : c.accent.withValues(alpha: 0.4))
                : c.surfaceHighest,
            borderRadius: BorderRadius.circular(trackHeight / 2),
            border: Border.all(
              color: value ? Colors.transparent : c.border,
            ),
          ),
          child: AnimatedBuilder(
            animation: _slide,
            builder: (BuildContext context, Widget? child) {
              // The overshoot: past the end and back. The curve only affects the
              // journey, so the resting position is always exact.
              final double eased =
                  Curves.easeOutBack.transform(_slide.value.clamp(0.0, 1.0));
              final double travel = trackWidth - thumb - inset * 2;
              return Stack(
                children: <Widget>[
                  Positioned(
                    left: inset + travel * eased,
                    top: inset,
                    child: AnimatedContainer(
                      duration: AstryxMotion.of(const Duration(milliseconds: 260)),
                      curve: AstryxMotion.emphasized,
                      width: thumb,
                      height: thumb,
                      decoration: BoxDecoration(
                        color: value ? c.onAccent : c.backgroundCard,
                        shape: BoxShape.circle,
                      ),
                      // The mark turns as it changes rather than being replaced:
                      // a tick appearing out of a cross is one thing becoming
                      // another, and a cut between two pictures is not.
                      child: AnimatedSwitcher(
                        duration: AstryxMotion.of(const Duration(milliseconds: 260)),
                        switchInCurve: AstryxMotion.emphasized,
                        switchOutCurve: AstryxMotion.emphasized,
                        transitionBuilder: (Widget child, Animation<double> a) {
                          return FadeTransition(
                            opacity: a,
                            child: RotationTransition(
                              turns: Tween<double>(begin: -0.35, end: 0)
                                  .animate(a),
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 0.5, end: 1)
                                    .animate(a),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: AceIconView(
                          key: ValueKey<bool>(value),
                          icon: value ? AceIcons.check : AceIcons.close,
                          size: 15,
                          color: value ? c.accent : c.iconSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

