import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mail_folder.dart';
import '../state/mail_controller.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import 'account_sheet.dart';
import 'avatar.dart';

class FolderRail extends StatelessWidget {
  const FolderRail({super.key});

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final MailController controller = context.watch<MailController>();

    return Container(
      width: 236,
      color: c.backgroundMuted,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _AccountHeader(email: controller.account?.email ?? ''),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AstryxSpace.s5,
                AstryxSpace.s2,
                AstryxSpace.s5,
                AstryxSpace.s3,
              ),
              child: Text('Folders', style: AstryxText.caption(c.textSecondary)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s2),
                itemCount: controller.folders.length,
                itemBuilder: (BuildContext context, int index) {
                  final MailFolder folder = controller.folders[index];
                  return _FolderTile(
                    folder: folder,
                    selected: controller.selectedFolder == folder,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Who you are signed in as, tappable to switch accounts.
class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final BorderRadius shape = BorderRadius.circular(AstryxRadius.element);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AstryxSpace.s2,
        AstryxSpace.s3,
        AstryxSpace.s2,
        0,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: shape,
          onTap: () {
            // Close the drawer first, so the sheet is not stacked over it.
            if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
              Navigator.of(context).pop();
            }
            showAccountSheet(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AstryxSpace.s3,
              vertical: AstryxSpace.s2,
            ),
            child: Row(
              children: <Widget>[
                MailAvatar(email: email, name: email, size: 30),
                const SizedBox(width: AstryxSpace.s3),
                Expanded(
                  child: Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: AstryxText.supporting(c.textPrimary),
                  ),
                ),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 18,
                  color: c.iconSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.folder, required this.selected});

  final MailFolder folder;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final Color foreground = selected ? c.textAccent : c.textSecondary;
    final BorderRadius shape = BorderRadius.circular(AstryxRadius.element);

    return Padding(
      padding: const EdgeInsets.only(bottom: AstryxSpace.s0_5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? c.accentMuted : Colors.transparent,
          borderRadius: shape,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: shape,
            onTap: () {
              context.read<MailController>().openFolder(folder);
              if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
                Navigator.of(context).pop();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AstryxSpace.s3,
                vertical: AstryxSpace.s3,
              ),
              child: Row(
                children: <Widget>[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: selected ? c.accent : c.borderEmphasized,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AstryxSpace.s3),
                  Expanded(
                    child: Text(
                      folder.label,
                      overflow: TextOverflow.ellipsis,
                      style: selected
                          ? AstryxText.bodyStrong(foreground)
                          : AstryxText.body(foreground),
                    ),
                  ),
                  if (folder.unseen > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AstryxSpace.s2,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(AstryxRadius.full),
                      ),
                      child: Text(
                        '${folder.unseen}',
                        style: AstryxText.caption(c.onAccent),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
