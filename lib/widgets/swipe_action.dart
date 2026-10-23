import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../models/swipe_action.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/haptics.dart';
import 'ace_icon_view.dart';

/// What a swipe action shows while it is being revealed: a mark, a word, and a
/// pair of colours.
///
/// The word matters as much as the mark. An envelope-with-a-down-arrow is an
/// archive only if you already know that; "Archive" is an archive to everyone.
typedef SwipeAppearance = ({
  AceIcon icon,
  String label,
  Color background,
  Color foreground,
});

SwipeAppearance swipeAppearance(
  SwipeAction action,
  AstryxColors c, {
  bool isSeen = true,
  bool isFlagged = false,
}) {
  switch (action) {
    case SwipeAction.archive:
      return (
        icon: AceIcons.archive,
        label: 'Archive',
        background: c.tertiaryContainer,
        foreground: c.onTertiaryContainer,
      );
    case SwipeAction.trash:
      return (
        icon: AceIcons.trash,
        label: 'Trash',
        background: c.errorMuted,
        foreground: c.onErrorMuted,
      );
    case SwipeAction.toggleRead:
      return (
        icon: isSeen ? AceIcons.mailUnread : AceIcons.mailOpen,
        label: isSeen ? 'Unread' : 'Read',
        background: c.secondaryContainer,
        foreground: c.onSecondaryContainer,
      );
    case SwipeAction.flag:
      return (
        icon: AceIcons.star,
        label: isFlagged ? 'Unstar' : 'Star',
        background: c.accentMuted,
        foreground: c.onAccentMuted,
      );
    case SwipeAction.none:
      return (
        icon: AceIcons.close,
        label: '',
        background: Colors.transparent,
        foreground: Colors.transparent,
      );
  }
}

/// A row that can be dragged sideways to reveal an action, then springs back.
///
/// The reveal is driven by a spring rather than a curve, and the action chip
/// morphs its corners as it appears — the same motion language as every other
/// press in the app. The gesture is felt as well as seen: a tick when the swipe
/// arms, and a heavier knock when the action would throw something away.
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
  final SwipeAppearance? startAppearance;
  final SwipeAppearance? endAppearance;

  @override
  State<AceSwipeTile> createState() => _AceSwipeTileState();
}

class _AceSwipeTileState extends State<AceSwipeTile>
    with TickerProviderStateMixin {
  /// The fraction of the row's width at which a swipe arms. Under a fifth, so
  /// the gesture is a flick rather than a haul across the screen.
  static const double _armFraction = 0.18;

  /// How far the row travels, as a fraction of its width — a little past the arm
  /// point, so the reveal finishes its morph just as the swipe commits.
  static const double _travelFraction = 0.3;

  /// Unbounded, so the spring can overshoot on the way back to rest.
  late final AnimationController _slide =
      AnimationController.unbounded(vsync: this, value: 0);

  /// The shred, when a swipe commits to the trash.
  ///
  /// It runs *before* the list is told, because the list removes the row the
  /// moment it hears — and a row that is gone has nothing left to animate. So
  /// the row is cut into strips here, they fall, and only then does the message
  /// actually go.
  late final AnimationController _shred = AnimationController(
    vsync: this,
    duration: AstryxMotion.of(const Duration(milliseconds: 420)),
  );

  /// How many strips the row is cut into. Seven reads as a shred; three reads
  /// as a slide.
  static const int _strips = 7;

  double _width = 320;

  /// Set the moment the swipe crosses its line, so the tick fires once per
  /// crossing rather than on every frame the finger moves.
  bool _armed = false;

  @override
  void dispose() {
    _slide.dispose();
    _shred.dispose();
    super.dispose();
  }

  bool get _startLive => widget.start != SwipeAction.none;
  bool get _endLive => widget.end != SwipeAction.none;

  SwipeAction _actionFor(double dx) => dx > 0 ? widget.start : widget.end;

  void _onUpdate(DragUpdateDetails details) {
    double next = _slide.value + details.delta.dx;
    // A direction with no action assigned does not move at all.
    if (next > 0 && !_startLive) next = 0;
    if (next < 0 && !_endLive) next = 0;
    next = next.clamp(-_width * _travelFraction, _width * _travelFraction);

    // Felt as the line is crossed, so the swipe says it is armed before it is
    // released — and un-arms if the finger comes back, so a second crossing is
    // felt too.
    final bool armed = next.abs() >= _width * _armFraction;
    if (armed && !_armed) {
      unawaited(
        _actionFor(next) == SwipeAction.trash
            ? AceHaptics.warn()
            : AceHaptics.select(),
      );
    }
    _armed = armed;
    _slide.value = next;
  }

  void _onEnd(DragEndDetails details) {
    final double value = _slide.value;
    final SwipeAction action = _actionFor(value);
    _armed = false;

    if (action != SwipeAction.none && value.abs() >= _width * _armFraction) {
      // A delete is the one that shreds. Archive and star are things that
      // happen *to* a message it keeps; the trash is where it stops being one,
      // and the animation is the only place that can be said.
      if (action == SwipeAction.trash && !AstryxMotion.reduced) {
        unawaited(_shredThen(action));
        return;
      }
      widget.onAction(action);
    }

    // Whatever happened, the row returns to rest on a spring — unless motion is
    // off, in which case it is simply at rest.
    if (AstryxMotion.reduced) {
      _slide.value = 0;
      return;
    }
    _slide.animateWith(
      SpringSimulation(AstryxMotion.press, _slide.value, 0, _slide.velocity),
    );
  }

  /// Shreds the row, then tells the list.
  Future<void> _shredThen(SwipeAction action) async {
    try {
      await _shred.forward();
    } finally {
      if (mounted) widget.onAction(action);
    }
  }

  /// The row, cut into [count] strips, each sliding a little further than the
  /// one above it and fading as it goes.
  Widget _shredded(Widget child) {
    return AnimatedBuilder(
      animation: _shred,
      builder: (BuildContext context, Widget? _) {
        final double t = _shred.value;
        return Stack(
          children: <Widget>[
            for (int i = 0; i < _strips; i++)
              Positioned.fill(
                child: ClipRect(
                  clipper: _StripClipper(i, _strips),
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Transform.translate(
                      // Further and faster for the lower strips, and alternating
                      // a little sideways: a shred that moved as one piece would
                      // be a slide with lines drawn on it.
                      offset: Offset(
                        t * (14 + i * 7),
                        t * (i.isEven ? 1 : -1) * (3 + i),
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
              final SwipeAction action = _actionFor(dx);
              // Saturated exactly at the arm point, so "the reveal is full" and
              // "the swipe will commit" are the same moment.
              final double reveal =
                  (dx.abs() / (_width * _armFraction)).clamp(0.0, 1.0);
              // How much of the chip the row has uncovered, over the whole
              // travel rather than over the arm point. The chip is revealed by
              // the row moving off it, which is what a swipe *is*.
              final double exposed =
                  (dx.abs() / (_width * _travelFraction)).clamp(0.0, 1.0);

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
                        exposed: exposed,
                      ),
                    ),
                  Transform.translate(
                    offset: Offset(dx, 0),
                    // The row lifts very slightly as it comes off its mark:
                    // enough to read as a card being picked up, not enough to
                    // look like it is being thrown.
                    child: Transform.scale(
                      scale: 1 - 0.012 * reveal,
                      child: child,
                    ),
                  ),
                ],
              );
            },
            child: _shred.value > 0
                ? _shredded(widget.child)
                : widget.child,
          ),
        );
      },
    );
  }
}

/// One horizontal strip of a row, as a clip.
class _StripClipper extends CustomClipper<Rect> {
  const _StripClipper(this.index, this.count);

  final int index;
  final int count;

  @override
  Rect getClip(Size size) {
    final double height = size.height / count;
    return Rect.fromLTWH(0, height * index, size.width, height);
  }

  @override
  bool shouldReclip(_StripClipper oldClipper) =>
      oldClipper.index != index || oldClipper.count != count;
}

class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.appearance,
    required this.fromLeft,
    required this.reveal,
    required this.exposed,
  });

  final SwipeAppearance appearance;
  final bool fromLeft;

  /// How far past the arm point the swipe has gone, 0 to 1.
  final double reveal;

  /// How much of the chip the row has uncovered, 0 to 1.
  final double exposed;

  @override
  Widget build(BuildContext context) {
    final bool armed = reveal >= 1;

    // Before the line is crossed the chip is there but quiet; past it, it is the
    // full colour, so the state is legible at a glance and not only by feel.
    final Color fill = armed
        ? appearance.background
        : Color.lerp(
            appearance.background.withValues(alpha: 0),
            appearance.background,
            reveal * 0.7,
          )!;

    // The word fades in behind the mark, so a half-pull reads as a mark and a
    // full one reads as an instruction.
    final Widget label = Opacity(
      opacity: ((reveal - 0.45) / 0.55).clamp(0.0, 1.0),
      child: Text(
        appearance.label,
        style: AstryxText.bodyStrong(appearance.foreground),
      ),
    );

    // The chip slides out from under the row rather than fading where it
    // stands. A reveal that is already in position when the drag begins is a
    // picture of a swipe; this is the swipe.
    final double hidden = (1 - exposed) * 56;

    return Container(
      margin: const EdgeInsets.only(bottom: AstryxSpace.s0_5),
      padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s5),
      alignment: fromLeft ? Alignment.centerLeft : Alignment.centerRight,
      decoration: BoxDecoration(
        color: fill,
        // The chip tightens as it is pulled out.
        borderRadius: BorderRadius.circular(
          AstryxRadius.container -
              (AstryxRadius.container - AstryxRadius.inner) * reveal,
        ),
      ),
      child: Transform.translate(
        offset: Offset(fromLeft ? -hidden : hidden, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!fromLeft) ...<Widget>[
              label,
              const SizedBox(width: AstryxSpace.s2),
            ],
            Transform.scale(
              // Grows out of the edge, and gives one push as the line is
              // crossed — the visual half of the tick the hand already felt.
              scale: (0.7 + 0.3 * reveal) * (armed ? 1.12 : 1),
              child: AceIconView(
                icon: appearance.icon,
                size: 22,
                color: appearance.foreground,
              ),
            ),
            if (fromLeft) ...<Widget>[
              const SizedBox(width: AstryxSpace.s2),
              label,
            ],
          ],
        ),
      ),
    );
  }
}
