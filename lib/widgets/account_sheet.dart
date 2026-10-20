import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../screens/sign_in_screen.dart';
import '../state/mail_controller.dart';
import '../state/mail_session.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/routes.dart';
import 'avatar.dart';

/// Bottom sheet listing every signed-in account: tap to switch, add another,
/// or remove one.
Future<void> showAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.astryx.backgroundSurface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AstryxRadius.page),
      ),
    ),
    builder: (BuildContext sheetContext) => const AccountSheet(),
  );
}

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final MailController controller = context.watch<MailController>();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AstryxSpace.s5,
              0,
              AstryxSpace.s5,
              AstryxSpace.s2,
            ),
            child: Text('Accounts', style: AstryxText.heading3(c.textPrimary)),
          ),
          for (int i = 0; i < controller.sessions.length; i++)
            _AccountTile(
              session: controller.sessions[i],
              index: i,
              active: i == controller.activeIndex,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AstryxSpace.s3,
              AstryxSpace.s2,
              AstryxSpace.s3,
              AstryxSpace.s3,
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AstryxRadius.element),
              ),
              leading: Icon(Icons.add_rounded, color: c.accent),
              title: Text(
                'Add another account',
                style: AstryxText.bodyStrong(c.textAccent),
              ),
              onTap: () {
                final NavigatorState nav = Navigator.of(context);
                nav.pop();
                nav.push(aceRoute(const SignInScreen(isAdding: true)));
              },
            ),
          ),
          Divider(height: 1, color: c.border),
          SwitchListTile(
            value: context.watch<Preferences>().showAvatars,
            onChanged: (bool value) =>
                context.read<Preferences>().setShowAvatars(value),
            title: Text(
              'Sender pictures',
              style: AstryxText.body(c.textPrimary),
            ),
            subtitle: Text(
              'Off by default. Turning this on sends a hash of every sender\'s '
              'address to gravatar.com, which is not anonymous — addresses are '
              'guessable and can be hashed by anyone.',
              style: AstryxText.supporting(c.textSecondary),
            ),
          ),
          const SizedBox(height: AstryxSpace.s2),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.session,
    required this.index,
    required this.active,
  });

  final MailSession session;
  final int index;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final String email = session.account.email;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AstryxSpace.s3,
        vertical: AstryxSpace.s0_5,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AstryxRadius.element),
        ),
        tileColor: active ? c.accentMuted : null,
        leading: MailAvatar(email: email, name: email, size: 40),
        title: Text(
          email,
          overflow: TextOverflow.ellipsis,
          style: AstryxText.body(active ? c.textAccent : c.textPrimary),
        ),
        subtitle: Text(
          active
              ? 'Active'
              : (session.isReady ? 'Signed in' : 'Connecting…'),
          style: AstryxText.supporting(c.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (active) Icon(Icons.check_circle_rounded, size: 20, color: c.accent),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: c.iconSecondary,
              ),
              tooltip: 'Remove account',
              onPressed: () => _remove(context),
            ),
          ],
        ),
        onTap: () {
          context.read<MailController>().switchTo(index);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _remove(BuildContext context) async {
    final MailController controller = context.read<MailController>();
    final NavigatorState nav = Navigator.of(context);
    final String email = session.account.email;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Remove account?'),
        content: Text(
          '$email will be signed out and its saved password deleted from this '
          'device.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await controller.removeAccount(index);
      nav.pop();
    }
  }
}
