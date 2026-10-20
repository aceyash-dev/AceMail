import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/message_summary.dart';
import '../state/mail_controller.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/dates.dart';
import 'astryx_widgets.dart';
import 'avatar.dart';

class MessageListPanel extends StatelessWidget {
  const MessageListPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final MailController controller = context.watch<MailController>();

    return Container(
      color: c.backgroundSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ListHeader(title: controller.selectedFolder?.label ?? 'Mail'),
          Divider(height: 1, color: c.border),
          Expanded(child: _body(context, controller)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, MailController controller) {
    final AstryxColors c = context.astryx;

    if (controller.loadingMessages) {
      return const Center(child: AceLoader());
    }

    // A failed fetch used to look like an empty folder. Say what happened.
    final String? error = controller.sessionError;
    if (controller.messages.isEmpty && error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AstryxSpace.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.error_outline_rounded, size: 28, color: c.error),
              const SizedBox(height: AstryxSpace.s3),
              Text(
                error,
                textAlign: TextAlign.center,
                style: AstryxText.supporting(c.error),
              ),
              const SizedBox(height: AstryxSpace.s4),
              AceButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: () =>
                    context.read<MailController>().refreshMessages(),
              ),
            ],
          ),
        ),
      );
    }

    if (controller.messages.isEmpty) {
      return Center(
        child: Text(
          controller.searchQuery == null
              ? 'This folder is empty.'
              : 'Nothing matched “${controller.searchQuery}”.',
          textAlign: TextAlign.center,
          style: AstryxText.body(c.textSecondary),
        ),
      );
    }

    // One extra row at the end when there are older messages to pull in.
    final int count =
        controller.messages.length + (controller.hasMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: () => context.read<MailController>().refreshMessages(),
      color: c.accent,
      backgroundColor: c.backgroundSurface,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => Divider(height: 1, color: c.border),
        itemBuilder: (BuildContext context, int index) {
          if (index >= controller.messages.length) {
            return _LoadMoreRow(loading: controller.loadingMore);
          }
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
    );
  }
}

class _LoadMoreRow extends StatelessWidget {
  const _LoadMoreRow({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AstryxSpace.s5),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : AceButton(
                label: 'Load older messages',
                icon: Icons.expand_more_rounded,
                onPressed: () => context.read<MailController>().loadMore(),
              ),
      ),
    );
  }
}

/// The folder name and a refresh button. Search lives in the app bar now, so
/// there is exactly one place to look for it.
class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AstryxSpace.s5,
        AstryxSpace.s4,
        AstryxSpace.s3,
        AstryxSpace.s3,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(title, style: AstryxText.heading2(c.textPrimary)),
          ),
          AceIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onPressed: () => context.read<MailController>().refreshMessages(),
          ),
        ],
      ),
    );
  }
}

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
      duration: Duration(milliseconds: 200 + (index.clamp(0, 8) * 24)),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 8),
          child: child,
        ),
      ),
      child: Material(
        color: selected ? c.accentMuted : c.backgroundSurface,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AstryxSpace.s5,
              vertical: AstryxSpace.s3,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                MailAvatar(
                  email: summary.fromEmail,
                  name: summary.fromName,
                  size: 40,
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
                              color: c.accent,
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
                    width: 8,
                    height: 8,
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
        ),
      ),
    );
  }
}
