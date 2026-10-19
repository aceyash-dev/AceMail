import 'package:flutter/material.dart';

import 'astryx_tokens.dart';

/// Astryx semantic type roles, composed on the geometric scale.
///
/// Astryx names families per role and leaves loading to the app; its own
/// default is Figtree. This theme uses **Questrial** for every role.
///
/// Questrial ships one weight — Regular. That is a real constraint, not an
/// oversight: hierarchy here is carried by size and colour, and the weight
/// values are kept so the roles stay faithful to Astryx the moment a weighted
/// companion is bundled alongside it. Emphasis that relies on weight alone
/// (bold in message bodies, for instance) will not visually differ until then.
abstract final class AstryxText {
  static const String family = 'Questrial';

  static TextStyle _style(double size, FontWeight weight, Color color) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: AstryxType.leading(size),
      );

  static TextStyle display1(Color c) =>
      _style(AstryxType.s5xl, AstryxType.semibold, c);
  static TextStyle display2(Color c) =>
      _style(AstryxType.s4xl, AstryxType.semibold, c);
  static TextStyle display3(Color c) =>
      _style(AstryxType.s3xl, AstryxType.semibold, c);

  static TextStyle heading1(Color c) =>
      _style(AstryxType.s2xl, AstryxType.semibold, c);
  static TextStyle heading2(Color c) =>
      _style(AstryxType.sXl, AstryxType.semibold, c);
  static TextStyle heading3(Color c) =>
      _style(AstryxType.sLg, AstryxType.semibold, c);
  static TextStyle heading4(Color c) =>
      _style(AstryxType.sBase, AstryxType.semibold, c);

  static TextStyle body(Color c) =>
      _style(AstryxType.sBase, AstryxType.normal, c);
  static TextStyle bodyStrong(Color c) =>
      _style(AstryxType.sBase, AstryxType.medium, c);
  static TextStyle label(Color c) =>
      _style(AstryxType.sSm, AstryxType.medium, c);
  static TextStyle supporting(Color c) =>
      _style(AstryxType.sSm, AstryxType.normal, c);
  static TextStyle caption(Color c) =>
      _style(AstryxType.sXs, AstryxType.medium, c);
}

/// Builds the app theme from the Astryx tokens for the given [brightness].
ThemeData buildAstryxTheme(Brightness brightness) {
  final AstryxColors c =
      brightness == Brightness.dark ? AstryxColors.dark : AstryxColors.light;

  final ColorScheme scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.accent,
    onSecondary: c.onAccent,
    error: c.error,
    onError: c.onError,
    surface: c.backgroundSurface,
    onSurface: c.textPrimary,
  );

  final TextTheme text = TextTheme(
    displayLarge: AstryxText.display1(c.textPrimary),
    displayMedium: AstryxText.display2(c.textPrimary),
    displaySmall: AstryxText.display3(c.textPrimary),
    headlineLarge: AstryxText.heading1(c.textPrimary),
    headlineMedium: AstryxText.heading2(c.textPrimary),
    headlineSmall: AstryxText.heading3(c.textPrimary),
    titleMedium: AstryxText.heading4(c.textPrimary),
    bodyLarge: AstryxText.body(c.textPrimary),
    bodyMedium: AstryxText.body(c.textPrimary),
    bodySmall: AstryxText.supporting(c.textSecondary),
    labelLarge: AstryxText.label(c.textSecondary),
    labelMedium: AstryxText.supporting(c.textSecondary),
    labelSmall: AstryxText.caption(c.textSecondary),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: AstryxText.family,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.backgroundBody,
    canvasColor: c.backgroundBody,
    dividerColor: c.border,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: c.backgroundSurface,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AstryxText.heading3(c.textPrimary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.backgroundMuted,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AstryxSpace.s3,
        vertical: AstryxSpace.s3,
      ),
      hintStyle: AstryxText.body(c.textDisabled),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AstryxRadius.element),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AstryxRadius.element),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AstryxRadius.element),
        borderSide: BorderSide(color: c.accent, width: 1.5),
      ),
    ),
  );
}
