import 'package:flutter/services.dart';

/// The app's taps, felt.
///
/// One place, so the whole app has the same vocabulary: a tick when something
/// becomes selected, a light knock when a gesture crosses its threshold, a
/// heavier one when something is about to be thrown away. Mild by design — a
/// mail client is used dozens of times a day, and anything louder stops being
/// feedback and becomes noise.
///
/// Every call is fire-and-forget and guarded: a platform without haptics, or one
/// that refuses, must not interrupt what the tap was for.
abstract final class AceHaptics {
  /// Off means off: the setting is checked by the caller, which already has the
  /// preferences to hand.
  static bool enabled = true;

  /// A tick: something became selected, or a swipe crossed a line.
  static Future<void> select() async {
    if (!enabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// A light knock: a long press, a button that does something.
  static Future<void> tap() async {
    if (!enabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// A heavier knock, for the irreversible ones.
  static Future<void> warn() async {
    if (!enabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }
}
