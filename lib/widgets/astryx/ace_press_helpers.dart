// ignore_for_file: unused_import
// Shared interaction math for Astryx's spring-pressed controls.
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../../theme/astryx_tokens.dart';

/// Clamp the spring value for shape interpolation without clamping its motion.
double acePressT(double press) => press.clamp(0.0, 1.0);

/// Radius interpolation shared by controls that morph between corner families.
BorderRadius acePressRadius(double press, double from, double to) =>
    BorderRadius.circular(lerpDouble(from, to, acePressT(press))!);

/// Scale a pressed control, respecting the global reduced-motion preference.
double acePressScale(
  double press,
  double amount, {
  bool respectReducedMotion = false,
}) =>
    respectReducedMotion && AstryxMotion.reduced ? 1 : 1 - amount * press;
