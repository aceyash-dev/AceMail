import 'package:flutter/material.dart';

/// Asks whether to close the app, from either entry point that can.
///
/// Both the sign-in screen and the mailbox need this, and they had drifted into
/// two copies of the same dialog.
Future<bool> confirmExit(BuildContext context) async {
  final bool? leave = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text('Exit Ace Mail?'),
      content: const Text('Ace Mail will close.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Stay'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Exit'),
        ),
      ],
    ),
  );
  return leave ?? false;
}
