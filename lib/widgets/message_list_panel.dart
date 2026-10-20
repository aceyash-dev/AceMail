import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart'
    show CupertinoSliverRefreshControl, RefreshIndicatorMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../models/message_summary.dart';
import '../models/swipe_action.dart';
import '../state/mail_controller.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/dates.dart';
import 'astryx_widgets.dart';
import 'avatar.dart';
import 'skeleton.dart';
import 'swipe_action.dart';

/// The message list, under a large title that collapses as it scrolls — the
/// Material 3 Expressive large app bar, scoped to this pane.
///
/// Pulling down turns into a shape morph rather than a spinner, and rows can be
/// swiped either way to act on them.
class MessageListPanel extends StatelessWidget {
  const MessageListPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final MailController controller = context.watch<MailController>();

    return Container(
      color: c.backgroundBody,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          CupertinoSliverRefreshControl(
            onRefresh: () => context.read<MailController>().refreshMessages(),
            refreshTriggerPullDistance: 110,
            refreshIndicatorExtent: 58,
            builder: _refreshIndicator,
          ),
          SliverAppBar.large(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: c.backgroundBody,
            surfaceTintColor: Colors.transparent,
            foregroundColor: c.textPrimary,
            expandedHeight: 132,
            title: Text(
              controller.selectedFolder?.label ?? 'Mail',
              style: AstryxText.heading2(c.textPrimary),
            ),
            actions: <Widget>[
              AceIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh',
                onPressed: () =>
                    context.read<MailController>().refreshMessages(),
              ),
              const SizedBox(width: AstryxSpace.s2),
            ],
          ),
          ..._slivers(context, controller),
        ],
      ),
    );
  }

  /// The pull is a drag, so the indicator is driven by it: the shape morphs as
  /// you pull, and only starts looping once the refresh is actually running.
  Widget _refreshIndicator(
    BuildContext context,
    RefreshIndicatorMode mode,
    double pulled,
    double trigger,
    double extent,
  ) {
    final bool running = mode == RefreshIndicatorMode.refresh ||
        mode == RefreshIndicatorMode.done;

    return SizedBox(
      height: extent,
      child: Center(
        child: AceLoader(
          size: 32,
          progress: running ? null : (pulled / trigger).clamp(0.0, 1.0),
        ),
      ),
    );
  }

  Preferences prefsOf(BuildContext context) => context.watch<Preferences>();

  List<Widget> _slivers(BuildContext context, MailController controller) {
    final AstryxColors c = context.astryx;

    if (controller.loadingMessages) {
      // Rows shaped like the ones coming, rather than a spinner on an empty
      // screen.
      return <Widget>[
        SliverToBoxAdapter(
          child: MessageListSkeleton(avatarSize: prefsOf(context).density.avatarSize),
        ),
      ];
    }

    // A failed fetch used to look like an empty folder. Say what happened.
    final String? error = controller.sessionError;
    if (controller.messages.isEmpty && error != null) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Centred(
            icon: Icons.error_outline_rounded,
            iconColor: c.error,
            message: error,
            action: AceButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              variant: AceButtonVariant.tonal,
              onPressed: () => context.read<MailController>().refreshMessages(),
            ),
          ),
        ),
      ];
    }

    if (controller.messages.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Centred(
            icon: Icons.mark_email_read_outlined,
            iconColor: c.iconDisabled,
            message: controller.searchQuery == null
                ? 'This folder is empty.'
                : 'Nothing matched “${controller.searchQuery}”.',
          ),
        ),
      ];
    }

    final Preferences prefs = context.watch<Preferences>();

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s2),
        sliver: SliverList.builder(
          itemCount: controller.messages.length,
          itemBuilder: (BuildContext context, int index) {
            final MessageSummary summary = controller.messages[index];
            return AceSwipeTile(
              key: ValueKey<int>(summary.uid),
              start: prefs.swipeStart,
              end: prefs.swipeEnd,
              startAppearance: swipeAppearance(
                prefs.swipeStart,
                c,
                isSeen: summary.isSeen,
                isFlagged: summary.isFlagged,
              ),
              endAppearance: swipeAppearance(
                prefs.swipeEnd,
                c,
                isSeen: summary.isSeen,
                isFlagged: summary.isFlagged,
              ),
              onAction: (SwipeAction action) =>
                  _applySwipe(context, summary, action),
              child: MessageTile(
                summary: summary,
                index: index,
                selected: controller.openSummary?.uid == summary.uid,
                onTap: () => context.read<MailController>().open(summary),
              ),
            );
          },
        ),
      ),
      if (controller.hasMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AstryxSpace.s6),
            child: Center(
              child: controller.loadingMore
                  ? const AceLoader(size: 34)
                  : AceButton(
                      label: 'Load older messages',
                      icon: Icons.expand_more_rounded,
                      variant: AceButtonVariant.tonal,
                      onPressed: () =>
                          context.read<MailController>().loadMore(),
                    ),
            ),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: AstryxSpace.s10)),
    ];
  }

  void _applySwipe(
    BuildContext context,
    MessageSummary summary,
    SwipeAction action,
  ) {
    final MailController controller = context.read<MailController>();
    switch (action) {
      case SwipeAction.archive:
        controller.archive(summary);
      case SwipeAction.trash:
        controller.delete(summary);
      case SwipeAction.toggleRead:
        controller.toggleRead(summary);
      case SwipeAction.flag:
        controller.toggleFlag(summary);
      case SwipeAction.none:
        break;
    }
  }
}

class _Centred extends StatelessWidget {
  const _Centred({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    return Padding(
      padding: const EdgeInsets.all(AstryxSpace.s6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 32, color: iconColor),
          const SizedBox(height: AstryxSpace.s3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AstryxText.body(c.textSecondary),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: AstryxSpace.s5),
            action!,
          ],
        ],
      ),
    );
  }
}

/// One message row. Springs on press, morphs its corners, and states unread
/// with weight and a dot rather than a colour change alone.
class MessageTile extends StatelessWidget {
  const MessageTile({
    super.key,
    required this.summary,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final MessageSummary summary;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final ListDensity density = context.watch<Preferences>().density;
    final bool unread = !summary.isSeen;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index.clamp(0, 8) * 28)),
      curve: AstryxMotion.emphasizedDecelerate,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(0, (1 - t) * 10), child: child),
      ),
      child: AceSpringy(
        onTap: onTap,
        builder: (BuildContext context, double press, bool hover) {
          final double t = press.clamp(0.0, 1.0);
          final BorderRadius shape = BorderRadius.circular(
            lerpDouble(AstryxRadius.container, AstryxRadius.inner, t)!,
          );

          return Transform.scale(
            scale: 1 - 0.02 * press,
            child: Container(
              margin: const EdgeInsets.only(bottom: AstryxSpace.s0_5),
              padding: EdgeInsets.symmetric(
                horizontal: AstryxSpace.s3,
                vertical: density.verticalPadding,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? c.accentMuted
                    : (hover ? c.surfaceHighest : Colors.transparent),
                borderRadius: shape,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  MailAvatar(
                    email: summary.fromEmail,
                    name: summary.fromName,
                    size: density.avatarSize,
                  ),
                  const SizedBox(width: AstryxSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                summary.fromName,
                                overflow: TextOverflow.ellipsis,
                                style: unread
                                    ? AstryxText.bodyStrong(c.textPrimary)
                                    : AstryxText.body(c.textSecondary),
                              ),
                            ),
                            const SizedBox(width: AstryxSpace.s2),
                            Text(
                              formatListDate(summary.date),
                              style: AstryxText.supporting(c.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: AstryxSpace.s0_5),
                        Row(
                          children: <Widget>[
                            if (summary.isFlagged) ...<Widget>[
                              Icon(
                                Icons.star_rounded,
                                size: 15,
                                color: c.tertiary,
                              ),
                              const SizedBox(width: AstryxSpace.s1),
                            ],
                            Expanded(
                              child: Text(
                                summary.subject,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: unread
                                    ? AstryxText.body(c.textPrimary)
                                    : AstryxText.body(c.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (unread) ...<Widget>[
                    const SizedBox(width: AstryxSpace.s2),
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(top: AstryxSpace.s1_5),
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
