import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../models/glass_mode.dart';
import '../theme/astryx_tokens.dart';

import '../services/platform_caps.dart';

abstract final class AceGlass {
  /// The Android API level, or null when this is not Android.
  ///
  /// Kept for the message below, which names the number. The capability itself
  /// is [PlatformCaps]'s answer now: two places deciding whether this device can
  /// blur is two places that can disagree.
  static int? get _androidApi =>
      PlatformCaps.isAndroid ? PlatformCaps.androidSdk : null;

  /// Whether this device can blur a backdrop at a price worth paying.
  static bool get capable => PlatformCaps.supportsBlur;

  /// What the device cannot do, in words, or null when it can do everything.
  ///
  /// Shown next to the setting, because "Always" that behaves like "Never" is a
  /// setting that looks broken.
  static String? get limitation {
    if (capable) return null;
    if (Platform.isAndroid) {
      final int? api = _androidApi;
      return api == null
          ? 'This device does not report its version, so the blur is off.'
          : 'Android 12 or later is needed for the blur. This is API $api.';
    }
    if (Platform.isLinux || Platform.isWindows) {
      return 'The blur is an iOS, macOS and Android 12+ effect. This build '
          'draws a flat surface.';
    }
    return 'This platform has no hardware backdrop blur.';
  }

  /// Whether the material is on, given the setting.
  static bool enabled(GlassMode mode) => switch (mode) {
        GlassMode.always => capable,
        GlassMode.never => false,
        GlassMode.auto => capable,
      };

  /// The same colour, inverted: light becomes dark and the hue goes with it.
  static Color _invert(Color colour) => Color.fromARGB(
        colour.a > 0 ? 1 : 0,
        255 - (colour.r * 255).round(),
        255 - (colour.g * 255).round(),
        255 - (colour.b * 255).round(),
      );

  /// A translucent surface, blurred when the device can.
  ///
  /// [child] is laid out normally; the blur is applied to whatever is behind it,
  /// so this must be used somewhere something *is* behind it.
  static Widget material(
    BuildContext context, {
    required Widget child,
    double blur = 24,
    double opacity = 0.72,
    BorderRadius? radius,
    bool bordered = false,
  }) {
    final AstryxColors c = context.astryx;
    final GlassMode mode = context.select<Preferences, GlassMode>(
      (Preferences prefs) => prefs.glass,
    );
    // The studio's dials, when it has been used. Null keeps the surface's own
    // numbers, so a person who never opens the studio gets the design as drawn.
    final double? studioBlur =
        context.select<Preferences, double?>((Preferences p) => p.glassBlur);
    final double? studioTint =
        context.select<Preferences, double?>((Preferences p) => p.glassTint);
    final bool invert =
        context.select<Preferences, bool>((Preferences p) => p.glassInvert);

    final double sigma = studioBlur ?? blur;
    final double alpha = studioTint ??
        (Platform.isIOS ? opacity - 0.14 : opacity);
    final BorderRadius shape =
        radius ?? BorderRadius.circular(AstryxRadius.container);

    final Widget surface = Container(
      decoration: BoxDecoration(
        color: enabled(mode)
            // Thinner on iOS: the material there is a sheet of light rather
            // than a pane of smoked glass. Inverted flips the tint, which is
            // the difference between frosted glass and smoked glass.
            ? (invert ? _invert(c.backgroundCard) : c.backgroundCard)
                .withValues(alpha: alpha.clamp(0.0, 1.0))
            // Opaque when it cannot blur. The colour is the same, so the layout
            // does not move when the material changes.
            : (invert ? _invert(c.backgroundCard) : c.backgroundCard),
        borderRadius: shape,
        border: bordered ? Border.all(color: c.border) : null,
      ),
      child: child,
    );

    if (!enabled(mode)) return surface;

    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          // A tile mode keeps the edges from going transparent where the blur
          // reaches past the source.
          tileMode: TileMode.mirror,
        ),
        child: surface,
      ),
    );
  }
}
