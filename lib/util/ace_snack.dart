import 'package:flutter/material.dart';

/// One way to say a thing happened.
///
/// A SnackBar everywhere, with the same shape and the same place on screen, so
/// a message is recognised before it is read. Destructive actions get an undo
/// on the bar itself, which is the only honest way to offer a delete in a list
/// you can swipe: the mistake is one tap away, so the way back must be too.
abstract final class AceSnack {
  static void show(BuildContext context, String message) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Says a thing happened, and offers to take it back.
  ///
  /// [duration] is how long the offer stays open. The caller passes the user's
  /// chosen window; the default is the same six seconds that window defaults to,
  /// so a caller with no settings to hand still gets the right behaviour.
  static void undo(
    BuildContext context,
    String message, {
    required VoidCallback onUndo,
    String label = 'Undo',
    Duration? duration,
  }) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration ?? const Duration(seconds: 6),
          action: SnackBarAction(label: label, onPressed: onUndo),
        ),
      );
  }
}
