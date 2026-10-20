import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/mail_controller.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/routes.dart';
import '../widgets/account_sheet.dart';
import '../widgets/astryx_widgets.dart';
import '../widgets/avatar.dart';
import '../widgets/confirm_exit.dart';
import '../widgets/folder_rail.dart';
import '../widgets/message_list_panel.dart';
import '../widgets/message_reader.dart';
import 'compose_screen.dart';
import 'tutorial_screen.dart';

/// The three-pane mailbox. Above [_wideBreakpoint] the folder rail, message
/// list and reader sit side by side; below it the reader takes the screen and
/// folders move into a drawer.
class MailboxScreen extends StatefulWidget {
  const MailboxScreen({super.key});

  static const double _wideBreakpoint = 940;

  @override
  State<MailboxScreen> createState() => _MailboxScreenState();
}

class _MailboxScreenState extends State<MailboxScreen> {
  MailController? _controller;
  String? _lastError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final MailController controller = context.read<MailController>();
    if (!identical(controller, _controller)) {
      _controller?.removeListener(_onControllerChanged);
      _controller = controller..addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// Surfaces a failure that would otherwise be swallowed — a folder that will
  /// not load, a message that will not delete.
  void _onControllerChanged() {
    final String? error = _controller?.sessionError;
    if (error == null) {
      _lastError = null;
      return;
    }
    if (error == _lastError) return;
    _lastError = error;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(error)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final MailController controller = context.watch<MailController>();
    final bool wide =
        MediaQuery.sizeOf(context).width >= MailboxScreen._wideBreakpoint;
    final bool reading = controller.openSummary != null;
    final String email = controller.account?.email ?? '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        // On a phone the first back closes the open message, not the app.
        if (!wide && controller.openSummary != null) {
          controller.closeMessage();
          return;
        }
        _confirmExit(context);
      },
      child: Scaffold(
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
            _AccountChip(
              email: email,
              showEmail: wide,
              onTap: () => showAccountSheet(context),
            ),
            AceIconButton(
              icon: Icons.help_outline_rounded,
              tooltip: 'How to sign in',
              onPressed: () =>
                  Navigator.of(context).push(aceRoute(const TutorialScreen())),
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
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (
                  Widget child,
                  Animation<double> animation,
                ) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: reading
                    ? MessageReader(
                        key: const ValueKey<String>('reader'),
                        onBack: controller.closeMessage,
                      )
                    : const MessageListPanel(key: ValueKey<String>('list')),
              ),
      ),
    );
  }

  void _compose(BuildContext context) {
    Navigator.of(context).push(aceRoute(const ComposeScreen()));
  }

  /// Shared with the sign-in screen, which needs the same question asked.
  Future<void> _confirmExit(BuildContext context) async {
    if (await confirmExit(context)) await SystemNavigator.pop();
  }
}

/// The signed-in account, tappable to switch accounts.
class _AccountChip extends StatelessWidget {
  const _AccountChip({
    required this.email,
    required this.showEmail,
    required this.onTap,
  });

  final String email;
  final bool showEmail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final BorderRadius shape = BorderRadius.circular(AstryxRadius.full);

    return Center(
      child: Material(
        color: c.backgroundMuted,
        borderRadius: shape,
        child: InkWell(
          borderRadius: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AstryxSpace.s2,
              vertical: AstryxSpace.s1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                MailAvatar(email: email, name: email, size: 26),
                if (showEmail) ...<Widget>[
                  const SizedBox(width: AstryxSpace.s2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      email,
                      overflow: TextOverflow.ellipsis,
                      style: AstryxText.supporting(c.textPrimary),
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: c.iconSecondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
