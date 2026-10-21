import 'package:flutter/material.dart';

import '../data/app_info.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import 'astryx_widgets.dart';

/// What Ace Mail is, and what it does with your credentials.
///
/// Shared by Settings and the sidebar, so the two cannot drift into telling
/// different stories about the same app.
Future<void> showAceAbout(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      final AstryxColors c = dialogContext.astryx;

      return AlertDialog(
        title: Row(
          children: <Widget>[
            const BrandMark(size: 34),
            const SizedBox(width: AstryxSpace.s3),
            Expanded(
              child: Text('Ace Mail', style: AstryxText.heading3(c.textPrimary)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppInfo.label.isEmpty ? 'Version unavailable' : AppInfo.label,
              style: AstryxText.label(c.textSecondary),
            ),
            const SizedBox(height: AstryxSpace.s4),
            Text(
              'A native IMAP and SMTP client for mobile and desktop. Any '
              'provider, no vendor lock-in.',
              style: AstryxText.body(c.textPrimary),
            ),
            const SizedBox(height: AstryxSpace.s3),
            Text(
              'Your credentials stay in this device\'s keychain and go only to '
              'your mail provider. Sender pictures are off by default, because '
              'looking them up tells a third party which domains are in your '
              'mail.',
              style: AstryxText.supporting(c.textSecondary),
            ),
          ],
        ),
        actions: <Widget>[
          AceButton(
            label: 'Close',
            variant: AceButtonVariant.tonal,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      );
    },
  );
}
