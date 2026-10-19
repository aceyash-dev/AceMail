import 'package:flutter/material.dart';

/// Astryx design tokens.
///
/// Ported from Meta's Astryx design system token reference
/// (astryx.atmeta.com/docs/tokens). Astryx is token-driven: components read
/// semantic tokens, never raw values. This file holds the raw scales —
/// typography, spacing, radius, control size — and [AstryxColors] holds the
/// semantic palette, themed with the Ace Mail brand exactly the way Astryx's
/// `defineTheme` overrides a theme.

/// Geometric type scale: round(14 × 1.2^step).
abstract final class AstryxType {
  static const double base = 14;
  static const double ratio = 1.2;

  static const double s4xs = 6;
  static const double s3xs = 7;
  static const double s2xs = 8;
  static const double sXs = 10;
  static const double sSm = 12;
  static const double sBase = 14;
  static const double sLg = 17;
  static const double sXl = 20;
  static const double s2xl = 24;
  static const double s3xl = 29;
  static const double s4xl = 35;
  static const double s5xl = 42;

  static const FontWeight normal = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  /// Astryx leading rule: a tiered target ratio snapped to the 4px grid.
  /// Small text (<20px) targets 1.5, medium (20–31px) 1.4, large (>=32px) 1.25.
  static double leading(double fontSize) {
    final double target = fontSize < 20 ? 1.5 : (fontSize < 32 ? 1.4 : 1.25);
    final double snapped = (fontSize * target / 4).round() * 4;
    return snapped / fontSize;
  }
}

/// 4px base-unit spacing scale (0 – 48px).
abstract final class AstryxSpace {
  static const double s0 = 0;
  static const double s0_5 = 2;
  static const double s1 = 4;
  static const double s1_5 = 6;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s7 = 28;
  static const double s8 = 32;
  static const double s9 = 36;
  static const double s10 = 40;
  static const double s11 = 44;
  static const double s12 = 48;
}

/// Radius by role, from a 4dp base unit.
abstract final class AstryxRadius {
  static const double none = 0;
  static const double inner = 8;
  static const double element = 12;
  static const double container = 16;
  static const double chat = 28;
  static const double page = 32;
  static const double full = 9999;
}

/// Fixed control heights, plus the minimum pointer target.
abstract final class AstryxSize {
  static const double elementSm = 28;
  static const double elementMd = 32;
  static const double elementLg = 36;
  static const double touchTarget = 44;
}

/// Semantic colour tokens. Each token carries a light and a dark value, as in
/// Astryx, so nothing in the app references a raw hex.
@immutable
class AstryxColors {
  const AstryxColors({
    required this.accent,
    required this.accentMuted,
    required this.onAccent,
    required this.neutral,
    required this.backgroundBody,
    required this.backgroundSurface,
    required this.backgroundCard,
    required this.backgroundPopover,
    required this.backgroundMuted,
    required this.overlay,
    required this.overlayHover,
    required this.overlayPressed,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.textAccent,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.iconDisabled,
    required this.border,
    required this.borderEmphasized,
    required this.success,
    required this.successMuted,
    required this.onSuccess,
    required this.error,
    required this.errorMuted,
    required this.onError,
    required this.warning,
    required this.warningMuted,
    required this.onWarning,
    required this.backgroundOrange,
    required this.borderOrange,
    required this.iconOrange,
    required this.textOrange,
  });

  final Color accent;
  final Color accentMuted;
  final Color onAccent;
  final Color neutral;
  final Color backgroundBody;
  final Color backgroundSurface;
  final Color backgroundCard;
  final Color backgroundPopover;
  final Color backgroundMuted;
  final Color overlay;
  final Color overlayHover;
  final Color overlayPressed;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color textAccent;
  final Color iconPrimary;
  final Color iconSecondary;
  final Color iconDisabled;
  final Color border;
  final Color borderEmphasized;
  final Color success;
  final Color successMuted;
  final Color onSuccess;
  final Color error;
  final Color errorMuted;
  final Color onError;
  final Color warning;
  final Color warningMuted;
  final Color onWarning;
  final Color backgroundOrange;
  final Color borderOrange;
  final Color iconOrange;
  final Color textOrange;

  /// Milk & Orange brand, light mode. Structural tokens keep Astryx's values;
  /// the brand overrides accent and the surface ramp.
  static const AstryxColors light = AstryxColors(
    accent: Color(0xFFFF6A1A),
    accentMuted: Color(0xFFFFE9D8),
    onAccent: Color(0xFFFFFFFF),
    neutral: Color(0x0F000000),
    backgroundBody: Color(0xFFFFFCF6),
    backgroundSurface: Color(0xFFFFFFFF),
    backgroundCard: Color(0xFFFFFFFF),
    backgroundPopover: Color(0xFFFFFFFF),
    backgroundMuted: Color(0xFFFBF4E9),
    overlay: Color(0x80000000),
    overlayHover: Color(0x0D000000),
    overlayPressed: Color(0x1A000000),
    textPrimary: Color(0xFF2A211B),
    textSecondary: Color(0xFF6B5D50),
    textDisabled: Color(0xFFA99A8B),
    textAccent: Color(0xFFCC4C06),
    iconPrimary: Color(0xFF2A211B),
    iconSecondary: Color(0xFF8C7B6B),
    iconDisabled: Color(0xFFB7A99A),
    border: Color(0x1A2A211B),
    borderEmphasized: Color(0xFFD8C7AC),
    success: Color(0xFF00490B),
    successMuted: Color(0xFFBCE0BB),
    onSuccess: Color(0xFFFFFFFF),
    error: Color(0xFF76000C),
    errorMuted: Color(0xFFFFC4BE),
    onError: Color(0xFFFFFFFF),
    warning: Color(0xFF4B3900),
    warningMuted: Color(0xFFFAE19E),
    onWarning: Color(0xFF111111),
    backgroundOrange: Color(0xFFFFE9D8),
    borderOrange: Color(0xFFFFC7A1),
    iconOrange: Color(0xFF622700),
    textOrange: Color(0xFF622700),
  );

  /// Milk & Orange brand, dark mode. Warm-shifted from Astryx's dark ramp.
  static const AstryxColors dark = AstryxColors(
    accent: Color(0xFFFF8A45),
    accentMuted: Color(0xFF3A2A1E),
    onAccent: Color(0xFF111111),
    neutral: Color(0x1AFFFFFF),
    backgroundBody: Color(0xFF1A1614),
    backgroundSurface: Color(0xFF241F1B),
    backgroundCard: Color(0xFF201B17),
    backgroundPopover: Color(0xFF201B17),
    backgroundMuted: Color(0xFF241F1B),
    overlay: Color(0xCC000000),
    overlayHover: Color(0x0DFFFFFF),
    overlayPressed: Color(0x1AFFFFFF),
    textPrimary: Color(0xFFFAF3E8),
    textSecondary: Color(0xFFB7A99A),
    textDisabled: Color(0xFF6B5D50),
    textAccent: Color(0xFFFFB37E),
    iconPrimary: Color(0xFFFAF3E8),
    iconSecondary: Color(0xFF9E8F80),
    iconDisabled: Color(0xFF6B5D50),
    border: Color(0x1AFFFFFF),
    borderEmphasized: Color(0xFF4A4038),
    success: Color(0xFFA4D6A3),
    successMuted: Color(0x3D90CA90),
    onSuccess: Color(0xFF111111),
    error: Color(0xFFFFC4BE),
    errorMuted: Color(0x3DFF9890),
    onError: Color(0xFF111111),
    warning: Color(0xFFF8D36A),
    warningMuted: Color(0x3DE2B623),
    onWarning: Color(0xFF111111),
    backgroundOrange: Color(0xFF503424),
    borderOrange: Color(0xFFDF843F),
    iconOrange: Color(0xFFFF9E55),
    textOrange: Color(0xFFFFB37E),
  );
}

/// Convenience accessor: `context.astryx` resolves the active mode's palette.
extension AstryxContext on BuildContext {
  AstryxColors get astryx => Theme.of(this).brightness == Brightness.dark
      ? AstryxColors.dark
      : AstryxColors.light;
}
