import 'package:flutter/material.dart';

import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';

/// A padded, rounded surface — Astryx's container role.
class AceSurface extends StatelessWidget {
  const AceSurface({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.border = true,
    this.radius = AstryxRadius.container,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final bool border;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.backgroundSurface,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: c.border) : null,
      ),
      child: child,
    );
  }
}

enum AceButtonVariant { primary, ghost, danger }

class AceButton extends StatelessWidget {
  const AceButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AceButtonVariant.ghost,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AceButtonVariant variant;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final (
      Color background,
      Color foreground,
      BorderSide? side,
    ) = switch (variant) {
      AceButtonVariant.primary => (c.accent, c.onAccent, null),
      AceButtonVariant.ghost => (
          c.backgroundSurface,
          c.textSecondary,
          BorderSide(color: c.border),
        ),
      AceButtonVariant.danger => (
          c.backgroundSurface,
          c.error,
          BorderSide(color: c.errorMuted),
        ),
    };

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: AstryxSpace.s2),
        ],
        Text(label, style: AstryxText.bodyStrong(foreground)),
      ],
    );

    final BorderRadius shape = BorderRadius.circular(AstryxRadius.element);
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: background,
        borderRadius: shape,
        child: InkWell(
          onTap: onPressed,
          borderRadius: shape,
          child: Container(
            height: AstryxSize.elementLg,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s4),
            decoration: BoxDecoration(
              borderRadius: shape,
              border: side == null ? null : Border.fromBorderSide(side),
            ),
            child: expand
                ? SizedBox(width: double.infinity, child: content)
                : content,
          ),
        ),
      ),
    );
  }
}

class AceIconButton extends StatelessWidget {
  const AceIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final Widget button = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AstryxRadius.element),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AstryxRadius.element),
        child: SizedBox(
          width: AstryxSize.touchTarget,
          height: AstryxSize.touchTarget,
          child: Icon(icon, size: 20, color: c.iconSecondary),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// The Ace Mail mark: an orange rounded square carrying the letter A.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[c.accent, c.textAccent],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        'A',
        style: AstryxText.heading2(c.onAccent)
            .copyWith(fontSize: size * 0.55, fontWeight: AstryxType.bold),
      ),
    );
  }
}

/// Circular initials chip. The colour is derived from the address so the same
/// sender keeps the same colour across sessions.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.initials,
    required this.seed,
    this.size = 40,
  });

  final String initials;
  final String seed;
  final double size;

  static const List<Color> _palette = <Color>[
    Color(0xFFFF6A1A),
    Color(0xFFEC5B0C),
    Color(0xFFE0894B),
    Color(0xFFC9761F),
    Color(0xFFB4551A),
    Color(0xFFD98A3D),
    Color(0xFF8C7B6B),
    Color(0xFFA85B22),
  ];

  @override
  Widget build(BuildContext context) {
    int hash = 0;
    for (final int code in seed.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    final Color color = _palette[hash % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        initials,
        style:
            AstryxText.bodyStrong(Colors.white).copyWith(fontSize: size * 0.36),
      ),
    );
  }
}
