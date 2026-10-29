import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../models/mail_folder.dart';
import '../screens/settings_screen.dart';
import '../screens/tutorial_screen.dart';
import '../state/mail_controller.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/routes.dart';
import 'about_dialog.dart';
import 'account_sheet.dart';
import 'astryx_widgets.dart';
import 'avatar.dart';
import 'ace_icon_view.dart';

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
              child: _FolderList(controller: controller),
            ),
            Divider(height: 1, color: c.border),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AstryxSpace.s2,
                vertical: AstryxSpace.s2,
              ),
              child: Column(
                children: <Widget>[
                  // Contacts is not a folder, and the rail is a list of
                  // folders. It stays reachable from the compose screen's
                  // suggestions and from the assistant's address book, which
                  // is where you want it — beside a recipient field, not above
                  // the mail.
                  _RailAction(
                    icon: AceIcons.settings,
                    label: 'Settings',
                    onTap: () {
                      _closeDrawerIfOpen(context);
                      Navigator.of(context).push(aceRoute(const SettingsScreen()));
                    },
                  ),
                  _RailAction(
                    icon: AceIcons.info,
                    label: 'About Ace Mail',
                    onTap: () => showAceAbout(context),
                  ),
                  // Only while there is nothing connected: once mail is
                  // flowing, an app-password walkthrough is clutter.
                  if (!context.watch<MailController>().isSignedIn)
                    _RailAction(
                      icon: AceIcons.help,
                      label: 'How to sign in',
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        Navigator.of(context)
                            .push(aceRoute(const TutorialScreen()));
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
    this.selected = false,
  });

  final AceIcon icon;
  final String label;
  final VoidCallback onTap;

  /// Whether this is the one being looked at, which fills it the way the
  /// folder rail fills the folder you are in.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return AceSpringy(
      onTap: onTap,
      builder: (BuildContext context, double press, bool hover) {
        final double t = press.clamp(0.0, 1.0);
        return Transform.scale(
          scale: 1 - 0.03 * press,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AstryxSpace.s3,
              vertical: AstryxSpace.s3,
            ),
            decoration: BoxDecoration(
              // Selected fills, the same way the folder you are in fills: the
              // stroke-only icon set has no second glyph to swap in.
              color: selected
                  ? c.accent
                  : (hover ? c.surfaceHighest : Colors.transparent),
              borderRadius: BorderRadius.circular(
                AstryxRadius.element -
                    (AstryxRadius.element - AstryxRadius.inner) * t,
              ),
            ),
            child: Row(
              children: <Widget>[
                AceIconView(
                  icon: icon,
                  size: 18,
                  color: selected ? c.onAccent : c.iconSecondary,
                ),
                const SizedBox(width: AstryxSpace.s3),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: AstryxText.body(
                      selected ? c.onAccent : c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                MailAvatar(email: email, name: email, size: 34, isSelf: true),
                const SizedBox(width: AstryxSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        email,
                        overflow: TextOverflow.ellipsis,
                        style: AstryxText.bodyStrong(c.textPrimary),
                      ),
                      Text(
                        'Switch account',
                        style: AstryxText.caption(c.textSecondary),
                      ),
                    ],
                  ),
                ),
                AceIconView(icon: 
                  AceIcons.unfold,
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
  const _FolderTile({
    required this.folder,
    required this.selected,
    required this.showCounts,
  });

  final MailFolder folder;
  final bool selected;

  /// Whether to draw the unread badge. Off is the "Unread counts on folders"
  /// switch; the rail still shows the folders, just without the counts.
  final bool showCounts;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    // Selected fills with the accent and inverts what sits on it. The hugeicons
    // set is stroke-only, so there is no filled glyph to swap in — a shape that
    // fills is how this app says "this one is current".
    final Color foreground = selected ? c.onAccent : c.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AstryxSpace.s0_5),
      child: AceSpringy(
        onTap: () {
          context.read<MailController>().openFolder(folder);
          _closeDrawerIfOpen(context);
        },
        builder: (BuildContext context, double press, bool hover) {
          final double t = press.clamp(0.0, 1.0);
          return Transform.scale(
            scale: 1 - 0.03 * press,
            child: AnimatedContainer(
              duration: AstryxMotion.fast,
              curve: AstryxMotion.emphasized,
              padding: const EdgeInsets.symmetric(
                horizontal: AstryxSpace.s3,
                vertical: AstryxSpace.s3,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? c.accent
                    : (hover ? c.surfaceHighest : Colors.transparent),
                borderRadius: BorderRadius.circular(
                  AstryxRadius.element -
                      (AstryxRadius.element - AstryxRadius.inner) * t,
                ),
              ),
              child: Row(
                children: <Widget>[
                  // The folder's own icon, from its role: an inbox looks like
                  // an inbox, Sent like a paper plane, Trash like a bin. A dot
                  // told you nothing except that you had picked it.
                  AnimatedScale(
                    duration: AstryxMotion.fast,
                    curve: AstryxMotion.emphasized,
                    scale: selected ? 1.0 : 0.92,
                    child: AceIconView(
                      icon: AceIcons.forFolder(folder.label),
                      size: 18,
                      color: selected ? c.onAccent : c.iconSecondary,
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
                  if (showCounts && folder.total > 0)
                    AnimatedContainer(
                      duration: AstryxMotion.fast,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AstryxSpace.s2,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        // Unread mail is the one thing a count should shout
                        // about, so the pill is accent only when something is
                        // waiting; otherwise it is a quiet grey.
                        color: selected
                            ? c.onAccent
                            : (folder.unseen > 0
                                ? c.accent
                                : c.surfaceHighest),
                        borderRadius: BorderRadius.circular(AstryxRadius.full),
                      ),
                      child: Text(
                        // Capped: a folder with 12,481 messages is a folder
                        // with "lots", and four digits in a pill is a pill
                        // that pushes the folder's name out of the rail.
                        folder.total > 999 ? '999+' : '${folder.total}',
                        style: AstryxText.caption(
                          selected
                              ? c.accent
                              : (folder.unseen > 0
                                  ? c.onAccent
                                  : c.textSecondary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The folders, in the order the person arranged them.
///
/// Long-press a folder and drag it. The order is kept by path, so it survives a
/// restart; a folder the person has not moved keeps its place after the ones
/// they have.
class _FolderList extends StatelessWidget {
  const _FolderList({required this.controller});

  final MailController controller;

  /// The server's folders, rearranged to the saved order.
  static List<MailFolder> ordered(List<MailFolder> folders, List<String> order) {
    if (order.isEmpty) return folders;
    final Map<String, int> rank = <String, int>{
      for (int i = 0; i < order.length; i++) order[i]: i,
    };
    final List<MailFolder> known = folders
        .where((MailFolder f) => rank.containsKey(f.path))
        .toList()
      ..sort((MailFolder a, MailFolder b) =>
          rank[a.path]!.compareTo(rank[b.path]!));
    final List<MailFolder> unknown =
        folders.where((MailFolder f) => !rank.containsKey(f.path)).toList();
    return <MailFolder>[...known, ...unknown];
  }

  @override
  Widget build(BuildContext context) {
    final Preferences prefs = context.watch<Preferences>();
    final List<MailFolder> folders =
        ordered(controller.folders, prefs.folderOrder);

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s2),
      buildDefaultDragHandles: false,
      itemCount: folders.length,
      // onReorderItem, not onReorder: the older callback hands over the index
      // as if the item were still in place, so every downward move landed one
      // short. The newer one does that adjustment itself.
      onReorderItem: (int oldIndex, int newIndex) {
        final List<String> paths = <String>[
          for (final MailFolder f in folders) f.path,
        ];
        paths.insert(newIndex, paths.removeAt(oldIndex));
        unawaited(context.read<Preferences>().setFolderOrder(paths));
      },
      itemBuilder: (BuildContext context, int index) {
        final MailFolder folder = folders[index];
        final MailFolder? chosen = controller.selectedFolder;
        return ReorderableDelayedDragStartListener(
          key: ValueKey<String>(folder.path),
          index: index,
          child: _FolderTile(
            folder: folder,
            // By value, not identity. The unified folder is built fresh on
            // every read — it carries a live unread count — so an identity
            // check could never be true and the selection never showed on it.
            selected: chosen != null &&
                chosen.role == folder.role &&
                chosen.path == folder.path,
            // Read where it is used. The "Unread counts on folders" switch used
            // to change nothing but its own state.
            showCounts: prefs.showFolderCounts,
          ),
        );
      },
    );
  }
}
