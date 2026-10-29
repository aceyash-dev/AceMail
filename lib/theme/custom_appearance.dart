import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The look the user assembles themselves: any accent colour, and a font from
/// their own files.
///
/// Kept apart from `astryx_theme.dart` because that file describes the design
/// system — what the app looks like when nobody has an opinion. This is the
/// escape hatch: one colour and one typeface, applied on top.
class CustomAppearance {
  const CustomAppearance._();

  /// The family the imported file is registered under. Fixed, because the font
  /// is a single file, not a family with weights.
  static const String fontFamily = 'AceCustomFont';

  /// `#RRGGBB` or `#AARRGGBB`, stored as a string so the preference file stays
  /// readable and a corrupt value loses the setting rather than the load.
  static Color? parseColour(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final String cleaned = raw.startsWith('#') ? raw.substring(1) : raw;
    if (cleaned.length != 6 && cleaned.length != 8) return null;
    final int? value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(cleaned.length == 6 ? 0xFF000000 | value : value);
  }

  static String encodeColour(Color colour) =>
      '#${colour.value.toRadixString(16).padLeft(8, '0')}';

  /// Registers [path] as the app font.
  ///
  /// Returns the family name, or null when the file is missing or is not a
  /// font. Callers must treat null as "keep the system face" — a settings file
  /// pointing at a deleted font must never stop the app drawing.
  static Future<String?> installFont(String? path) async {
    if (path == null || path.isEmpty) return null;
    final File file = File(path);
    if (!file.existsSync()) return null;
    try {
      final Uint8List bytes = await file.readAsBytes();
      final FontLoader loader = FontLoader(fontFamily)
        ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
      await loader.load();
      return fontFamily;
    } catch (_) {
      return null;
    }
  }
}
