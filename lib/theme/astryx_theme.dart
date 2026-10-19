import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'astryx_tokens.dart';

/// Astryx semantic type roles, composed on the geometric scale.
///
/// Roles pair size, weight and leading so call sites express intent — heading,
/// body, label, supporting — instead of raw numbers. Astryx's default families
/// are Figtree for headings and body; this theme keeps Figtree for headings and
/// assigns Instrument Sans to body and UI text, which is a custom theme in
/// Astryx terms, not a departure from it.
abstract final class AstryxText {
  static TextStyle _heading(double size, FontWeight weight, Color color) =>
      GoogleFonts.figtree(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: AstryxType.leading(size),
      );

  static TextStyle _body(double size, FontWeight weight, Color color) =>
      GoogleFonts.instrumentSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: AstryxType.leading(size),
      );

  static TextStyle display1(Color c) =>
      _heading(AstryxType.s5xl, AstryxType.semibold, c);
  static TextStyle display2(Color c) =>
      _heading(AstryxType.s4xl, AstryxType.semibold, c);
  static TextStyle display3(Color c) =>
      _heading(AstryxType.s3xl, AstryxType.semibold, c);

  static TextStyle heading1(Color c) =>
      _heading(AstryxType.s2xl, AstryxType.semibold, c);
  static TextStyle heading2(Color c) =>
      _heading(AstryxType.sXl, AstryxType.semibold, c);
  static TextStyle heading3(Color c) =>
      _heading(AstryxType.sLg, AstryxType.semibold, c);
  static TextStyle heading4(Color c) =>
      _heading(AstryxType.sBase, AstryxType.semibold, c);

  static TextStyle body(Color c) =>
      _body(AstryxType.sBase, AstryxType.normal, c);
  static TextStyle bodyStrong(Color c) =>
      _body(AstryxType.sBase, AstryxType.medium, c);
  static TextStyle label(Color c) =>
      _body(AstryxType.sSm, AstryxType.medium, c);
  static TextStyle supporting(Color c) =>
      _body(AstryxType.sSm, AstryxType.normal, c);
  static TextStyle caption(Color c) =>
      _body(AstryxType.sXs, AstryxType.medium, c);
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
