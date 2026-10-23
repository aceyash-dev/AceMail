import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../models/glass_mode.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';

abstract final class AceGlass {
  /// The Android API level, or null when this is not Android.
  ///
  /// Read from the platform's own version string — `Android 13 (API 33)` — so
  /// that a device reporting something unexpected falls back to no blur rather
  /// than to a stall.
  static int? get _androidApi {
    if (!Platform.isAndroid) return null;
    final RegExpMatch? match =
        RegExp(r'API (\d+)').firstMatch(Platform.operatingSystemVersion);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// Whether this device can blur a backdrop at a price worth paying.
  static bool get capable {
    if (Platform.isIOS || Platform.isMacOS) return true;
    final int? api = _androidApi;
    return api != null && api >= 31;
  }

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
    return 'This platform has no hardware backdrop blur.';
  }

  /// Whether the material is on, given the setting.
  static bool enabled(GlassMode mode) => switch (mode) {
        GlassMode.always => capable,
        GlassMode.never => false,
        GlassMode.auto => capable,
      };

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
    final BorderRadius shape =
        radius ?? BorderRadius.circular(AstryxRadius.container);

    final Widget surface = Container(
      decoration: BoxDecoration(
        color: enabled(mode)
            // Thinner on iOS: the material there is a sheet of light rather
            // than a pane of smoked glass.
            ? c.backgroundCard
                .withValues(alpha: Platform.isIOS ? opacity - 0.14 : opacity)
            // Opaque when it cannot blur. The colour is the same, so the layout
            // does not move when the material changes.
            : c.backgroundCard,
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
          sigmaX: blur,
          sigmaY: blur,
          // A tile mode keeps the edges from going transparent where the blur
          // reaches past the source.
          tileMode: TileMode.mirror,
        ),
        child: surface,
      ),
    );
  }
}
