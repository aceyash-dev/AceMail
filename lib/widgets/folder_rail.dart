import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mail_folder.dart';
import '../screens/settings_screen.dart';
import '../screens/tutorial_screen.dart';
import '../state/mail_controller.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/routes.dart';
import 'account_sheet.dart';
import 'avatar.dart';

/// The rail is a drawer on a phone, so anything that pushes a screen has to
/// close it first — otherwise the two stack.
void _closeDrawerIfOpen(BuildContext context) {
  if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
    Navigator.of(context).pop();
  }
}

/// Folders, who you are signed in as, and the app's settings and help.
///
/// Everything that is not mail lives here rather than in the app bar, so the
/// top of the screen stays about the messages.
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
            Divider(height: 1, color: c.border),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AstryxSpace.s2,
                vertical: AstryxSpace.s2,
              ),
              child: Column(
                children: <Widget>[
                  _RailAction(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () {
                      _closeDrawerIfOpen(context);
                      Navigator.of(context).push(aceRoute(const SettingsScreen()));
                    },
                  ),
                  _RailAction(
                    icon: Icons.help_outline_rounded,
                    label: 'How to sign in',
                    onTap: () {
                      _closeDrawerIfOpen(context);
                      Navigator.of(context).push(aceRoute(const TutorialScreen()));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A settings or help entry at the foot of the rail.
class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final BorderRadius shape = BorderRadius.circular(AstryxRadius.element);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AstryxSpace.s3,
            vertical: AstryxSpace.s3,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: c.iconSecondary),
              const SizedBox(width: AstryxSpace.s3),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AstryxText.body(c.textSecondary),
                ),
              ),
            ],
          ),
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
            _closeDrawerIfOpen(context);
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
              _closeDrawerIfOpen(context);
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
