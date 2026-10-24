// ignore_for_file: unused_import
// Pure sender-seed hashing into the Astryx tonal palette.
import 'package:flutter/material.dart';
import '../../theme/astryx_theme.dart';

Color aceAvatarTone(String seed, AstryxColors colors) {
  final int hash = seed.codeUnits.fold<int>(7, (int value, int unit) => value * 31 + unit);
  final List<Color> tones = <Color>[
    colors.accentMuted,
    colors.secondaryContainer,
    colors.tertiaryContainer,
    colors.surfaceHighest,
  ];
  return tones[hash.abs() % tones.length];
}
