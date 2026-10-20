import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/message_summary.dart';
import '../state/mail_controller.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/dates.dart';
import 'astryx_widgets.dart';
import 'avatar.dart';

/// The message list, under a large title that collapses as it scrolls — the
/// Material 3 Expressive large app bar, scoped to this pane.
class MessageListPanel extends StatelessWidget {
  const MessageListPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final MailController controller = context.watch<MailController>();

    return Container(
      color: c.backgroundBody,
      child: RefreshIndicator(
        onRefresh: () => context.read<MailController>().refreshMessages(),
        color: c.accent,
        backgroundColor: c.backgroundSurface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
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
      ),
    );
  }

  List<Widget> _slivers(BuildContext context, MailController controller) {
    final AstryxColors c = context.astryx;

    if (controller.loadingMessages) {
      return <Widget>[
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: AceLoader()),
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

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s2),
        sliver: SliverList.builder(
          itemCount: controller.messages.length,
          itemBuilder: (BuildContext context, int index) {
            final MessageSummary summary = controller.messages[index];
            return MessageTile(
              key: ValueKey<int>(summary.uid),
              summary: summary,
              index: index,
              selected: controller.openSummary?.uid == summary.uid,
              onTap: () => context.read<MailController>().open(summary),
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
    final bool unread = !summary.isSeen;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index.clamp(0, 8) * 28)),
      curve: AstryxMotion.emphasizedDecelerate,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 10), child: child),
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
              padding: const EdgeInsets.symmetric(
                horizontal: AstryxSpace.s3,
                vertical: AstryxSpace.s3,
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
                    size: 42,
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
