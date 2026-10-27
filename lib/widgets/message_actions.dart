import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mail_folder.dart';
import '../models/message_summary.dart';
import '../screens/compose_screen.dart';
import '../state/mail_controller.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/ace_snack.dart';
import 'chyme_sheet.dart';
import 'folder_picker.dart';
import 'settings_group.dart';

/// What you can do with a message, without opening it.
///
/// Long-pressing a row used to start picking messages, which is one gesture
/// doing the job of two: the thing people reach for on a message is an action,
/// and picking is something you decide to do rather than something a press
/// assumes. The sheet is the actions; picking is one of them.
Future<void> showMessageActionsSheet(
  BuildContext context,
  MessageSummary summary,
) {
  final AstryxColors c = context.astryx;
  final MailController controller = context.read<MailController>();
  final bool unread = !summary.isSeen;

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      void close() => Navigator.of(sheetContext).pop();

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: AstryxSpace.s4),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AstryxSpace.s5,
                  0,
                  AstryxSpace.s5,
                  AstryxSpace.s3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      summary.subject.isEmpty
                          ? '(no subject)'
                          : summary.subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AstryxText.heading4(c.textPrimary),
                    ),
                    const SizedBox(height: AstryxSpace.s0_5),
                    Text(
                      summary.fromName.isEmpty
                          ? summary.fromEmail
                          : '${summary.fromName} · ${summary.fromEmail}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AstryxText.supporting(c.textSecondary),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.border),
              SettingsRow(
                icon: AceIcons.reply,
                title: 'Reply',
                onTap: () async {
                  close();
                  await openComposeSheet(
                    context,
                    initialTo: summary.fromEmail,
                    initialSubject: summary.subject.toLowerCase().startsWith('re:')
                        ? summary.subject
                        : 'Re: ${summary.subject}',
                  );
                },
              ),
              SettingsRow(
                icon: AceIcons.forward,
                title: 'Forward',
                onTap: () async {
                  close();
                  await openComposeSheet(
                    context,
                    initialSubject:
                        summary.subject.toLowerCase().startsWith('fwd:')
                            ? summary.subject
                            : 'Fwd: ${summary.subject}',
                  );
                },
              ),
              SettingsRow(
                icon: unread ? AceIcons.mailOpen : AceIcons.mailUnread,
                title: unread ? 'Mark read' : 'Mark unread',
                onTap: () {
                  close();
                  if (unread) {
                    controller.markRead(summary);
                  } else {
                    controller.toggleRead(summary);
                  }
                },
              ),
              SettingsRow(
                icon: summary.isFlagged ? AceIcons.star : AceIcons.starOff,
                title: summary.isFlagged ? 'Remove star' : 'Star',
                onTap: () {
                  close();
                  controller.toggleFlag(summary);
                },
              ),
              if (!controller.inTrash)
                SettingsRow(
                  icon: AceIcons.archive,
                  title: 'Archive',
                  onTap: () {
                    close();
                    controller.archive(summary);
                  },
                ),
              if (!controller.inTrash)
                SettingsRow(
                  icon: AceIcons.folder,
                  title: 'Move to…',
                  onTap: () async {
                    close();
                    final MailFolder? target = await showFolderPicker(
                      context,
                      folders: controller.filingFolders,
                      currentPath: summary.folderPath ??
                          controller.currentFolderPath,
                    );
                    if (target == null) return;
                    await controller.moveMessageTo(summary, target);
                    if (context.mounted) {
                      AceSnack.show(context, 'Moved to ${target.label}.');
                    }
                  },
                ),
              SettingsRow(
                icon: controller.inJunk ? AceIcons.inbox : AceIcons.warning,
                title: controller.inJunk ? 'Not spam' : 'Mark as spam',
                onTap: () {
                  close();
                  if (controller.inJunk) {
                    controller.markNotSpam(summary);
                  } else {
                    controller.markSpam(summary);
                  }
                },
              ),
              SettingsRow(
                icon: AceIcons.trash,
                title: controller.inTrash ? 'Delete permanently' : 'Delete',
                onTap: () {
                  close();
                  controller.delete(summary, permanently: controller.inTrash);
                },
              ),
              Divider(height: 1, color: c.border),
              // The assistant, on a message you have not opened: it reads the
              // message itself, which is why the question is asked by uid.
              SettingsRow(
                icon: AceIcons.chyme,
                title: 'Ask Chyme about this',
                subtitle: 'What it is asking for, and whether it needs you today.',
                onTap: () {
                  close();
                  ChymeSheet.show(
                    context,
                    seed: 'Read message ${summary.uid} and tell me what it is '
                        'asking for, and whether it needs a reply today.',
                  );
                },
              ),
              SettingsRow(
                icon: AceIcons.selectAll,
                title: 'Select',
                subtitle: 'Pick this message, and then others.',
                onTap: () {
                  close();
                  controller.toggleSelect(summary.uid);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
