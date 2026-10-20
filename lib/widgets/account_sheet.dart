import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/settings_screen.dart';
import '../screens/sign_in_screen.dart';
import '../state/mail_controller.dart';
import '../state/mail_session.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/routes.dart';
import 'astryx_widgets.dart';
import 'avatar.dart';

/// Bottom sheet listing every signed-in account: tap to switch, add another,
/// or remove one.
///
/// Grouped the way the rest of the app's lists are — a section of accounts,
/// then a section of actions.
Future<void> showAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AstryxSpace.s6,
                AstryxSpace.s1,
                AstryxSpace.s6,
                AstryxSpace.s4,
              ),
              child: Text('Accounts', style: AstryxText.heading2(c.textPrimary)),
            ),
            _Group(
              children: <Widget>[
                for (int i = 0; i < controller.sessions.length; i++)
                  _AccountTile(
                    session: controller.sessions[i],
                    index: i,
                    active: i == controller.activeIndex,
                  ),
              ],
            ),
            _Group(
              children: <Widget>[
                AceListTile(
                  leading: Icon(Icons.add_rounded, color: c.accent),
                  title: 'Add another account',
                  onTap: () {
                    final NavigatorState nav = Navigator.of(context);
                    nav.pop();
                    nav.push(aceRoute(const SignInScreen(isAdding: true)));
                  },
                ),
                AceListTile(
                  leading: Icon(
                    Icons.settings_outlined,
                    color: c.iconSecondary,
                  ),
                  title: 'Settings',
                  onTap: () {
                    final NavigatorState nav = Navigator.of(context);
                    nav.pop();
                    nav.push(aceRoute(const SettingsScreen()));
                  },
                ),
              ],
            ),
            const SizedBox(height: AstryxSpace.s5),
          ],
        ),
      ),
    );
  }
}

/// A tonal card holding a run of rows.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AstryxSpace.s3,
        0,
        AstryxSpace.s3,
        AstryxSpace.s3,
      ),
      child: AceSurface(
        squircle: true,
        padding: const EdgeInsets.symmetric(vertical: AstryxSpace.s1),
        child: Column(
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: AstryxSpace.s11,
                  endIndent: AstryxSpace.s3,
                  color: c.border,
                ),
              children[i],
            ],
          ],
        ),
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

    return AceListTile(
      selected: active,
      onTap: () {
        context.read<MailController>().switchTo(index);
        Navigator.of(context).pop();
      },
      padding: const EdgeInsets.symmetric(
        horizontal: AstryxSpace.s3,
        vertical: AstryxSpace.s2,
      ),
      leading: MailAvatar(email: email, name: email, size: 42),
      title: email,
      subtitle: active
          ? 'Active'
          : (session.isReady ? 'Signed in' : 'Connecting…'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (active)
            Icon(Icons.check_circle_rounded, size: 20, color: c.accent),
          AceIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Remove account',
            variant: AceIconButtonVariant.danger,
            size: AstryxSize.elementMd,
            onPressed: () => _remove(context),
          ),
        ],
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
