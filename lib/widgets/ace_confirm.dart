import 'package:flutter/material.dart';

/// A yes-or-no question, in one place.
///
/// The same dialog was written five times across the app — twice in the Chyme
/// sheet alone — and five copies is five places for the wording, the button
/// order or the destructive colouring to differ. One helper, so the question
/// somebody is asked about deleting their mail looks the same whether it came
/// from the toolbar, a swipe or the assistant.
///
/// Returns false when the dialog is dismissed, because "the person did not say
/// yes" and "the person said no" have to mean the same thing to the caller.
Future<bool> aceConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  required String cancel,
  bool destructive = false,
}) async {
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialog) {
      final ColorScheme scheme = Theme.of(dialog).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: scheme.error)
                : null,
            child: Text(confirm),
          ),
        ],
      );
    },
  );
  return yes ?? false;
}
