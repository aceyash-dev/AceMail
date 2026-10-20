import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/mail_controller.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../widgets/astryx_widgets.dart';
import '../widgets/folder_rail.dart';
import '../widgets/message_list_panel.dart';
import '../widgets/message_reader.dart';
import 'compose_screen.dart';
import 'tutorial_screen.dart';

/// The three-pane mailbox. Above [_wideBreakpoint] the folder rail, message
/// list and reader sit side by side; below it the reader takes the screen and
/// folders move into a drawer.
class MailboxScreen extends StatelessWidget {
  const MailboxScreen({super.key});

  static const double _wideBreakpoint = 940;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final MailController controller = context.watch<MailController>();
    final bool wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final bool reading = controller.openSummary != null;

    return Scaffold(
      backgroundColor: c.backgroundBody,
      appBar: AppBar(
        titleSpacing: AstryxSpace.s4,
        title: Row(
          children: <Widget>[
            const BrandMark(size: 30),
            const SizedBox(width: AstryxSpace.s3),
            Text('Ace Mail', style: AstryxText.heading3(c.textPrimary)),
          ],
        ),
        actions: <Widget>[
          if (wide) ...<Widget>[
            Center(
              child: Text(
                controller.account?.email ?? '',
                style: AstryxText.supporting(c.textSecondary),
              ),
            ),
            const SizedBox(width: AstryxSpace.s3),
            AceButton(
              label: 'Compose',
              icon: Icons.edit_outlined,
              variant: AceButtonVariant.primary,
              onPressed: () => _compose(context),
            ),
            const SizedBox(width: AstryxSpace.s3),
          ],
          AceIconButton(
            icon: Icons.help_outline_rounded,
            tooltip: 'How to sign in',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TutorialScreen()),
            ),
          ),
          AceIconButton(
            icon: Icons.logout_rounded,
            tooltip: 'Sign out',
            onPressed: () => _signOut(context),
          ),
          const SizedBox(width: AstryxSpace.s2),
        ],
      ),
      drawer: wide ? null : const Drawer(child: FolderRail()),
      floatingActionButton: wide
          ? null
          : FloatingActionButton(
              onPressed: () => _compose(context),
              backgroundColor: c.accent,
              foregroundColor: c.onAccent,
              child: const Icon(Icons.edit_outlined),
            ),
      body: wide
          ? Row(
              children: <Widget>[
                const FolderRail(),
                VerticalDivider(width: 1, color: c.border),
                const SizedBox(width: 380, child: MessageListPanel()),
                VerticalDivider(width: 1, color: c.border),
                const Expanded(child: MessageReader()),
              ],
            )
          : (reading
              ? MessageReader(onBack: controller.closeMessage)
              : const MessageListPanel()),
    );
  }

  void _compose(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const ComposeScreen()));
  }

  Future<void> _signOut(BuildContext context) async {
    final MailController controller = context.read<MailController>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Saved credentials will be removed from this device.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await controller.signOut();
  }
}
