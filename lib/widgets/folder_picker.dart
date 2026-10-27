import 'package:flutter/material.dart';

import '../models/mail_folder.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import 'ace_icon_view.dart';
import 'astryx_widgets.dart';
import 'settings_group.dart';

/// The folders a message can be filed into, as a sheet.
///
/// Filing is the oldest thing a mail client does after reading, and it was the
/// one thing this app could not do at all: archive moved a message to one fixed
/// folder, and everything else was a decision made by the app rather than by
/// the person. This is the missing half — every folder the account has, in the
/// order the rail shows them, minus the one the message is already in.
Future<MailFolder?> showFolderPicker(
  BuildContext context, {
  required List<MailFolder> folders,
  String? currentPath,
  String title = 'Move to',
}) {
  final AstryxColors c = context.astryx;
  final List<MailFolder> choices = <MailFolder>[
    for (final MailFolder folder in folders)
      if (folder.path != currentPath) folder,
  ];

  return showModalBottomSheet<MailFolder>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AstryxSpace.s5,
                0,
                AstryxSpace.s5,
                AstryxSpace.s3,
              ),
              child: Text(title, style: AstryxText.heading3(c.textPrimary)),
            ),
            if (choices.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AstryxSpace.s5,
                  0,
                  AstryxSpace.s5,
                  AstryxSpace.s5,
                ),
                child: Text(
                  'This account has nowhere else to file it.',
                  style: AstryxText.body(c.textSecondary),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: AstryxSpace.s4),
                  itemCount: choices.length,
                  itemBuilder: (BuildContext context, int index) {
                    final MailFolder folder = choices[index];
                    return SettingsRow(
                      icon: AceIcons.folder,
                      title: folder.label,
                      subtitle: folder.unseen > 0
                          ? '${folder.unseen} unread'
                          : null,
                      trailing: folder.role == FolderRole.inbox
                          ? AceIconView(
                              icon: AceIcons.inbox,
                              size: 18,
                              color: c.iconDisabled,
                            )
                          : null,
                      onTap: () => Navigator.of(sheetContext).pop(folder),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
