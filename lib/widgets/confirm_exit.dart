import 'package:flutter/material.dart';

/// Asks whether to archive a message, when the setting is on.
///
/// The swipe and the selection toolbar both archive, and both honour "ask
/// before archiving", so the question lives in one place rather than being
/// written out twice and drifting apart.
Future<bool> confirmArchive(BuildContext context) async {
  final bool? go = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text('Archive this message?'),
      content: const Text('It moves out of the inbox and into Archive.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Archive'),
        ),
      ],
    ),
  );
  return go ?? false;
}

/// Asks before a permanent delete, which is the one action that cannot be
/// undone.
///
/// Every permanent-delete path asks — the reader, "Empty trash", and the
/// selection toolbar, which used to expunge the selected messages out of the
/// Trash with no question at all.
Future<bool> confirmPermanentDelete(
  BuildContext context, {
  required int count,
}) async {
  final bool one = count == 1;
  final bool? go = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(
        one ? 'Delete permanently?' : 'Delete $count messages permanently?',
      ),
      content: Text(
        one
            ? 'This message is in the Trash, so it will be deleted permanently '
                'and cannot be recovered.'
            : 'These messages are in the Trash, so they will be deleted '
                'permanently and cannot be recovered.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete permanently'),
        ),
      ],
    ),
  );
  return go ?? false;
}

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
