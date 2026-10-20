import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';

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

/// A padded, rounded surface — Astryx's container role, on the tonal ramp.
class AceSurface extends StatelessWidget {
  const AceSurface({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.border = true,
    this.radius = AstryxRadius.container,
    this.squircle = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final bool border;
  final double radius;

  /// Continuous corners, for the large surfaces expressive M3 softens.
  final bool squircle;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final Decoration decoration = BoxDecoration(
      color: color ?? c.backgroundSurface,
      borderRadius: squircle ? null : BorderRadius.circular(radius),
      border: border ? Border.all(color: c.border) : null,
    );

    if (!squircle) {
      // Clipped, so a child with its own rounded background — a selected row in
      // a group, say — cannot spill past the card's corners.
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(padding: padding, decoration: decoration, child: child),
      );
    }

    return ClipPath(
      clipper: const AceSquircleClipper(),
      child: CustomPaint(
        painter: _SquircleSurface(
          color: color ?? c.backgroundSurface,
          border: border ? c.border : null,
        ),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}

/// Clips to a continuous corner. Shared by every surface that wants the shape.
class AceSquircleClipper extends CustomClipper<Path> {
  const AceSquircleClipper({this.exponent = 4});

  final double exponent;

  @override
  Path getClip(Size size) =>
      AstryxShape.squircle(Offset.zero & size, exponent: exponent);

  @override
  bool shouldReclip(covariant AceSquircleClipper oldClipper) =>
      oldClipper.exponent != exponent;
}

class _SquircleSurface extends CustomPainter {
  const _SquircleSurface({required this.color, required this.border});

  final Color color;
  final Color? border;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawPath(
      AstryxShape.squircle(rect),
      Paint()..color = color,
    );
    if (border != null) {
      // Inset by a full pixel so the clip does not shave the stroke.
      canvas.drawPath(
        AstryxShape.squircle(rect.deflate(1)),
        Paint()
          ..color = border!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SquircleSurface old) =>
      old.color != color || old.border != border;
}

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
  final IconData? icon;
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
    final double iconSize = size == AceButtonSize.large ? 22 : 18;

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
          Icon(icon, size: iconSize, color: foreground),
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
          final double t = press.clamp(0.0, 1.0);
          final BorderRadius shape = BorderRadius.circular(
            lerpDouble(AstryxRadius.full, AstryxRadius.lg, t)!,
          );
          final Color fill = hover && background == Colors.transparent
              ? c.overlayHover
              : background;

          return Transform.scale(
            scale: 1 - 0.045 * press,
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
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final AceIconButtonVariant variant;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    final (Color background, Color foreground) = switch (variant) {
      AceIconButtonVariant.standard => (
          selected ? c.accentMuted : Colors.transparent,
          selected ? c.onAccentMuted : c.iconSecondary,
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
        final double t = press.clamp(0.0, 1.0);
        // A circular button tightens into a squircle as it is pressed — the
        // shape morph, at the smallest scale it happens in the app.
        final BorderRadius shape = BorderRadius.circular(
          lerpDouble(AstryxRadius.full, AstryxRadius.element, t)!,
        );
        return Transform.scale(
          scale: 1 - 0.06 * press,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: hover && background == Colors.transparent
                  ? c.overlayHover
                  : background,
              borderRadius: shape,
            ),
            child: Icon(icon, size: size * 0.5, color: foreground),
          ),
        );
      },
    );

    return tooltip == null
        ? button
        : Tooltip(message: tooltip!, child: button);
  }
}

/// The expressive FAB: a pill that springs, and collapses to an icon when
/// there is not room for its label.
class AceFab extends StatelessWidget {
  const AceFab({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.extended = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return AceSpringy(
      enabled: onPressed != null,
      onTap: onPressed,
      builder: (BuildContext context, double press, bool hover) {
        final double t = press.clamp(0.0, 1.0);
        final BorderRadius shape = BorderRadius.circular(
          lerpDouble(AstryxRadius.lg, AstryxRadius.full, t)!,
        );
        return Transform.scale(
          scale: 1 - 0.04 * press,
          child: Container(
            height: AstryxSize.elementXl,
            padding: EdgeInsets.symmetric(
              horizontal: extended ? AstryxSpace.s5 : AstryxSpace.s4,
            ),
            decoration: BoxDecoration(
              color: c.accentMuted,
              borderRadius: shape,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 22, color: c.onAccentMuted),
                if (extended) ...<Widget>[
                  const SizedBox(width: AstryxSpace.s3),
                  Text(
                    label,
                    style: AstryxText.bodyStrong(c.onAccentMuted),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

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
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final Color foreground = selected ? c.onAccentMuted : c.textSecondary;

    return AceSpringy(
      enabled: onTap != null,
      onTap: onTap,
      builder: (BuildContext context, double press, bool hover) {
        final double t = press.clamp(0.0, 1.0);
        final BorderRadius shape = BorderRadius.circular(
          lerpDouble(AstryxRadius.full, AstryxRadius.container, t)!,
        );
        return Transform.scale(
          scale: 1 - 0.04 * press,
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
                  Icon(icon, size: 16, color: foreground),
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
        final double t = press.clamp(0.0, 1.0);
        final BorderRadius shape = BorderRadius.circular(
          lerpDouble(AstryxRadius.container, AstryxRadius.inner, t)!,
        );
        return Transform.scale(
          scale: 1 - 0.02 * press,
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

/// A floating pill toolbar — the expressive M3 toolbar, docked at the bottom of
/// a surface where a thumb can reach it.
class AceToolbarAction {
  const AceToolbarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final bool destructive;
}

class AceToolbar extends StatelessWidget {
  const AceToolbar({super.key, required this.actions});

  final List<AceToolbarAction> actions;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s2),
      decoration: BoxDecoration(
        color: c.backgroundPopover,
        borderRadius: BorderRadius.circular(AstryxRadius.full),
        border: Border.all(color: c.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.overlay.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final AceToolbarAction action in actions)
            AceIconButton(
              icon: action.icon,
              tooltip: action.tooltip,
              onPressed: action.onPressed,
              selected: action.selected,
              variant: action.destructive
                  ? AceIconButtonVariant.danger
                  : (action.selected
                      ? AceIconButtonVariant.tonal
                      : AceIconButtonVariant.standard),
            ),
        ],
      ),
    );
  }
}

/// The Ace Mail mark: the milk envelope on the brand orange, expressed on a
/// 108-unit grid so the in-app mark, the launcher icon and the splash mark are
/// one drawing rather than three near-misses.
///
/// The flap is a real notch cut out of the envelope, so whatever is behind it
/// shows through — which is what lets the same path sit on a gradient launcher
/// tile and on a flat one.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: _BrandMarkPainter()),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter();

  /// The envelope, with the flap removed. Shared with the vector drawables by
  /// using the same numbers.
  static Path envelopePath(double unit) {
    final Path body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(28 * unit, 37 * unit, 52 * unit, 34 * unit),
          Radius.circular(6 * unit),
        ),
      );
    // The flap is a chevron band: the outer triangle minus the inner one. The
    // vector drawable expresses the same thing as three subpaths with evenOdd.
    final Path outer = Path()
      ..moveTo(28 * unit, 37 * unit)
      ..lineTo(54 * unit, 58 * unit)
      ..lineTo(80 * unit, 37 * unit)
      ..close();
    final Path inner = Path()
      ..moveTo(33 * unit, 37 * unit)
      ..lineTo(54 * unit, 53 * unit)
      ..lineTo(75 * unit, 37 * unit)
      ..close();
    final Path band = Path.combine(PathOperation.difference, outer, inner);
    return Path.combine(PathOperation.difference, body, band);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double unit = size.width / 108.0;
    canvas.drawPath(
      AstryxShape.squircle(Offset.zero & size),
      Paint()..color = AstryxBrand.orange,
    );
    canvas.drawPath(
      envelopePath(unit),
      Paint()..color = AstryxBrand.milk,
    );
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) => false;
}

/// The Material 3 Expressive loading indicator: a shape that morphs.
///
/// Expressive loading is not a spinner. It is a single form that continuously
/// flows between shape families — circle, soft square, a four-lobed clover,
/// squircle — while turning slowly. The morph is one continuous formula rather
/// than a cross-fade, so the surface genuinely deforms.
///
/// It is deliberately not the envelope: at 18px inside a button there is no
/// room for a mark, and a morphing shape reads as "working" at any size.
class AceLoader extends StatefulWidget {
  const AceLoader({super.key, this.size = 40, this.color, this.progress});

  final double size;
  final Color? color;

  /// When set (0..1), the morph is driven by that value instead of looping —
  /// which is how pull-to-refresh turns a drag into a shape change.
  final double? progress;

  @override
  State<AceLoader> createState() => _AceLoaderState();
}

class _AceLoaderState extends State<AceLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.progress == null) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant AceLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress == null && !_controller.isAnimating) {
      _controller.repeat();
    } else if (widget.progress != null && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, _) => CustomPaint(
          painter: _ShapeMorphPainter(
            t: widget.progress?.clamp(0.0, 1.0) ?? _controller.value,
            color: widget.color ?? c.accent,
          ),
        ),
      ),
    );
  }
}

/// One shape family the indicator flows through. `exponent` is the
/// superellipse power (2 is a circle, higher is squarer); `lobes` is how deep
/// the ripple is and `lobeCount` how many there are, which is what turns the
/// same formula into a clover, a flower or a star.
class _Form {
  const _Form(this.exponent, this.lobes, this.lobeCount);

  final double exponent;
  final double lobes;
  final double lobeCount;
}

class _ShapeMorphPainter extends CustomPainter {
  const _ShapeMorphPainter({required this.t, required this.color});

  final double t;
  final Color color;

  static const List<_Form> _forms = <_Form>[
    _Form(2.0, 0.00, 4), // circle
    _Form(5.2, 0.00, 4), // soft square
    _Form(2.4, 0.16, 4), // clover
    _Form(4.0, 0.05, 4), // squircle
    _Form(3.0, 0.12, 3), // rounded triangle
    _Form(2.0, 0.22, 6), // flower
    _Form(6.4, 0.00, 4), // square
    _Form(2.6, 0.09, 5), // star
  ];

  static const int _samples = 132;

  @override
  void paint(Canvas canvas, Size size) {
    // Walk the form list and back again, so the loop has no seam.
    final double cycle = t * 2 * (_forms.length - 1);
    final int index = cycle.floor().clamp(0, _forms.length - 2);
    final double raw = cycle - index;
    final double eased = Curves.easeInOut.transform(raw);

    final _Form a = _forms[index];
    final _Form b = _forms[index + 1];
    final double exponent = lerpDouble(a.exponent, b.exponent, eased)!;
    final double lobes = lerpDouble(a.lobes, b.lobes, eased)!;
    final double lobeCount = lerpDouble(a.lobeCount, b.lobeCount, eased)!;

    final double radius = size.width / 2;
    final Offset centre = size.center(Offset.zero);
    // A slow, constant turn, so the morph never looks like a pulse.
    final double rotation = t * 2 * math.pi;

    final Path path = Path();
    for (int i = 0; i <= _samples; i++) {
      final double theta = (i / _samples) * 2 * math.pi;
      final double cosT = math.cos(theta);
      final double sinT = math.sin(theta);

      // The radial form of a superellipse: |cos|^n + |sin|^n raised to -1/n.
      final double superellipse = math.pow(
        math.pow(cosT.abs(), exponent) + math.pow(sinT.abs(), exponent),
        -1 / exponent,
      ).toDouble();

      final double ripple = 1 + lobes * math.cos(lobeCount * theta);

      final double r = radius * superellipse * ripple;
      final double x = centre.dx + r * math.cos(theta + rotation);
      final double y = centre.dy + r * math.sin(theta + rotation);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ShapeMorphPainter old) =>
      old.t != t || old.color != color;
}

/// A sender's initials on a tonal tile, used wherever there is no picture.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.initials,
    this.size = 40,
    this.tone,
    this.seed,
  });

  final String initials;
  final double size;
  final Color? tone;

  /// What the tone is derived from — usually the address, so one sender keeps
  /// one colour across the app.
  final String? seed;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final Color background = tone ?? _toneFor(seed ?? initials, c);

    return CustomPaint(
      painter: _AvatarTile(color: background),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            initials,
            style: AstryxText.bodyStrong(c.onAccentMuted).copyWith(
              fontSize: size * 0.36,
              color: c.onAccentMuted,
            ),
          ),
        ),
      ),
    );
  }

  /// A stable tone per sender, drawn from the scheme's container roles so the
  /// avatars stay inside the expressive palette.
  static Color _toneFor(String seed, AstryxColors c) {
    final int hash = seed.codeUnits.fold<int>(7, (int a, int b) => a * 31 + b);
    final List<Color> tones = <Color>[
      c.accentMuted,
      c.secondaryContainer,
      c.tertiaryContainer,
      c.surfaceHighest,
    ];
    return tones[hash.abs() % tones.length];
  }
}

class _AvatarTile extends CustomPainter {
  const _AvatarTile({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      AstryxShape.squircle(Offset.zero & size),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarTile old) => old.color != color;
}
