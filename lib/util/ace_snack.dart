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
  static void undo(
    BuildContext context,
    String message, {
    required VoidCallback onUndo,
    String label = 'Undo',
  }) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(label: label, onPressed: onUndo),
        ),
      );
  }
}
