import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../models/swipe_action.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_tokens.dart';
import 'ace_icon_view.dart';

/// The icon and tone a swipe action shows while it is being revealed.
({AceIcon icon, Color background, Color foreground}) swipeAppearance(
  SwipeAction action,
  AstryxColors c, {
  bool isSeen = true,
  bool isFlagged = false,
}) {
  switch (action) {
    case SwipeAction.archive:
      return (
        icon: AceIcons.archive,
        background: c.tertiaryContainer,
        foreground: c.onTertiaryContainer,
      );
    case SwipeAction.trash:
      return (
        icon: AceIcons.trash,
        background: c.errorMuted,
        foreground: c.onErrorMuted,
      );
    case SwipeAction.toggleRead:
      return (
        icon: isSeen
            ? AceIcons.mailUnread
            : AceIcons.mailOpen,
        background: c.secondaryContainer,
        foreground: c.onSecondaryContainer,
      );
    case SwipeAction.flag:
      return (
        icon: isFlagged ? AceIcons.star : AceIcons.star,
        background: c.accentMuted,
        foreground: c.onAccentMuted,
      );
    case SwipeAction.none:
      return (
        icon: AceIcons.close,
        background: Colors.transparent,
        foreground: Colors.transparent,
      );
  }
}

/// A row that can be dragged sideways to reveal an action, then springs back.
///
/// The reveal is driven by a spring rather than a curve, and the action chip
/// morphs its corners as it appears — the same motion language as every other
/// press in the app.
class AceSwipeTile extends StatefulWidget {
  const AceSwipeTile({
    super.key,
    required this.child,
    required this.start,
    required this.end,
    required this.onAction,
    this.startAppearance,
    this.endAppearance,
  });

  final Widget child;

  /// Revealed by dragging right, on the left of the row.
  final SwipeAction start;

  /// Revealed by dragging left, on the right of the row.
  final SwipeAction end;

  final void Function(SwipeAction action) onAction;

  /// Overrides so a row can say what the action will do to *this* message.
  final ({AceIcon icon, Color background, Color foreground})? startAppearance;
  final ({AceIcon icon, Color background, Color foreground})? endAppearance;

  @override
  State<AceSwipeTile> createState() => _AceSwipeTileState();
}

class _AceSwipeTileState extends State<AceSwipeTile>
    with SingleTickerProviderStateMixin {
  /// Unbounded, so the spring can overshoot on the way back to rest.
  late final AnimationController _slide =
      AnimationController.unbounded(vsync: this, value: 0);

  double _width = 320;

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  bool get _startLive => widget.start != SwipeAction.none;
  bool get _endLive => widget.end != SwipeAction.none;

  void _onUpdate(DragUpdateDetails details) {
    double next = _slide.value + details.delta.dx;
    // A direction with no action assigned does not move at all.
    if (next > 0 && !_startLive) next = 0;
    if (next < 0 && !_endLive) next = 0;
    _slide.value = next.clamp(-_width * 0.42, _width * 0.42);
  }

  void _onEnd(DragEndDetails details) {
    final double value = _slide.value;
    final SwipeAction action = value > 0 ? widget.start : widget.end;

    if (action != SwipeAction.none && value.abs() >= _width * 0.26) {
      widget.onAction(action);
    }
    // Whatever happened, the row returns to rest on a spring.
    _slide.animateWith(
      SpringSimulation(AstryxMotion.press, _slide.value, 0, _slide.velocity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _width = constraints.maxWidth;

        return GestureDetector(
          onHorizontalDragUpdate: _onUpdate,
          onHorizontalDragEnd: _onEnd,
          child: AnimatedBuilder(
            animation: _slide,
            builder: (BuildContext context, Widget? child) {
              final double dx = _slide.value;
              final bool fromLeft = dx > 0;
              final SwipeAction action =
                  fromLeft ? widget.start : widget.end;
              final double reveal =
                  (dx.abs() / (_width * 0.3)).clamp(0.0, 1.0);

              return Stack(
                children: <Widget>[
                  if (action != SwipeAction.none && dx.abs() > 1)
                    Positioned.fill(
                      child: _Reveal(
                        appearance: fromLeft
                            ? (widget.startAppearance ??
                                swipeAppearance(action, c))
                            : (widget.endAppearance ??
                                swipeAppearance(action, c)),
                        fromLeft: fromLeft,
                        reveal: reveal,
                      ),
                    ),
                  Transform.translate(offset: Offset(dx, 0), child: child),
                ],
              );
            },
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.appearance,
    required this.fromLeft,
    required this.reveal,
  });

  final ({AceIcon icon, Color background, Color foreground}) appearance;
  final bool fromLeft;
  final double reveal;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AstryxSpace.s0_5),
      padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s5),
      alignment: fromLeft ? Alignment.centerLeft : Alignment.centerRight,
      decoration: BoxDecoration(
        color: appearance.background,
        // The chip tightens as it is pulled out.
        borderRadius: BorderRadius.circular(
          AstryxRadius.container -
              (AstryxRadius.container - AstryxRadius.inner) * reveal,
        ),
      ),
      child: Transform.scale(
        scale: 0.7 + 0.3 * reveal,
        child: AceIconView(icon: 
          appearance.icon,
          size: 22,
          color: appearance.foreground,
        ),
      ),
    );
  }
}
