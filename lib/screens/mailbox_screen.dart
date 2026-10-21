import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../state/mail_controller.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/routes.dart';
import '../widgets/astryx_widgets.dart';
import '../widgets/confirm_exit.dart';
import '../widgets/folder_rail.dart';
import '../widgets/message_list_panel.dart';
import '../widgets/message_reader.dart';
import 'compose_screen.dart';

/// The three-pane mailbox. Above [_wideBreakpoint] the folder rail, message
/// list and reader sit side by side; below it the reader takes the screen and
/// folders move into a drawer.
///
/// The app bar carries the brand and search. Accounts, help and settings live
/// in the rail, so the top of the screen stays about the mail.
class MailboxScreen extends StatefulWidget {
  const MailboxScreen({super.key});

  static const double _wideBreakpoint = 940;

  @override
  State<MailboxScreen> createState() => _MailboxScreenState();
}

class _MailboxScreenState extends State<MailboxScreen> {
  MailController? _controller;
  String? _lastError;

  final TextEditingController _search = TextEditingController();
  Timer? _searchDebounce;
  bool _searching = false;

  /// The folder the current search belongs to, so a folder change can end it.
  String? _searchFolder;

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
    _searchDebounce?.cancel();
    _search.dispose();
    _controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// Surfaces a failure that would otherwise be swallowed — a folder that will
  /// not load, a message that will not delete — and closes search when the
  /// ground moves under it.
  void _onControllerChanged() {
    final MailController? controller = _controller;
    if (controller == null) return;

    final String? error = controller.sessionError;
    if (error == null) {
      _lastError = null;
    } else if (error != _lastError) {
      _lastError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(error)),
        );
      });
    }

    if (!_searching) return;
    final bool folderMoved = controller.selectedFolder?.path != _searchFolder;
    final bool openedMessage = controller.openSummary != null;
    if (folderMoved || openedMessage) {
      // The session has already reset its own query in the folder case, so only
      // the field and the mode need clearing.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _exitSearch(clearQuery: false);
      });
    }
  }

  void _openSearch() {
    setState(() {
      _searching = true;
      _searchFolder = context.read<MailController>().selectedFolder?.path;
    });
  }

  void _exitSearch({bool clearQuery = true}) {
    _searchDebounce?.cancel();
    _search.clear();
    if (clearQuery) context.read<MailController>().clearSearch();
    if (mounted) setState(() => _searching = false);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      context.read<MailController>().search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final MailController controller = context.watch<MailController>();
    final bool wide =
        MediaQuery.sizeOf(context).width >= MailboxScreen._wideBreakpoint;
    final bool reading = controller.openSummary != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_searching) {
          _exitSearch();
          return;
        }
        // On a phone the first back closes the open message, not the app.
        if (!wide && controller.openSummary != null) {
          controller.closeMessage();
          return;
        }
        _confirmExit(context);
      },
      // Pull down to refresh; on a keyboard, Ctrl/Cmd+R does the same, because
      // a drag is awkward with a mouse.
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
              context.read<MailController>().refreshMessages(),
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
              context.read<MailController>().refreshMessages(),
        },
        child: Scaffold(
        backgroundColor: c.backgroundBody,
        appBar: AppBar(
          titleSpacing: AstryxSpace.s4,
          leading: _searching
              ? AceIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Close search',
                  onPressed: _exitSearch,
                )
              : null,
          // The folder you are in, not the app's name. The name is on the
          // launcher and the splash; here the space is better spent telling you
          // where you are.
          title: _searching
              ? _searchField(c)
              : Text(
                  controller.selectedFolder?.label ?? 'Mail',
                  style: AstryxText.heading3(c.textPrimary),
                ),
          actions: <Widget>[
            if (!_searching && !(reading && !wide))
              AceIconButton(
                icon: Icons.search_rounded,
                tooltip: 'Search',
                onPressed: _openSearch,
              ),
            const SizedBox(width: AstryxSpace.s2),
          ],
        ),
        // The sidebar on a phone. Without this the rail is unreachable and
        // there is no way to change folder at all.
        drawer: wide
            ? null
            : Drawer(
                width: 304,
                backgroundColor: c.backgroundSurface,
                child: const FolderRail(),
              ),
        // Not while a message is open: the reader's floating toolbar occupies
        // the same corner, and the two overlap.
        floatingActionButton: wide || reading
            ? null
            : AceFab(
                label: 'Compose',
                icon: Icons.edit_outlined,
                onPressed: () => _compose(context),
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
      ),
    );
  }

  Widget _searchField(AstryxColors c) {
    // A pill, matching every other control in the expressive layer.
    return Container(
      height: AstryxSize.elementLg,
      padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s4),
      decoration: BoxDecoration(
        color: c.backgroundMuted,
        borderRadius: BorderRadius.circular(AstryxRadius.full),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.search_rounded, size: 18, color: c.iconSecondary),
          const SizedBox(width: AstryxSpace.s2),
          Expanded(
            child: TextField(
              controller: _search,
              autofocus: true,
              onChanged: _onSearchChanged,
              onSubmitted: (String value) {
                _searchDebounce?.cancel();
                context.read<MailController>().search(value);
              },
              textInputAction: TextInputAction.search,
              style: AstryxText.body(c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search this folder',
                // Every state, not just the resting one: leaving the focused
                // border unset lets the theme's outline draw inside the pill.
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintStyle: AstryxText.body(c.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _compose(BuildContext context) {
    Navigator.of(context).push(aceRoute(const ComposeScreen()));
  }

  Future<void> _confirmExit(BuildContext context) async {
    // The user can turn the confirmation off; then leaving just leaves.
    final Preferences prefs = context.read<Preferences>();
    if (prefs.confirmExit && !await confirmExit(context)) return;
    await SystemNavigator.pop();
  }
}
