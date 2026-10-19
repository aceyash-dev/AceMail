import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/message_summary.dart';
import '../state/mail_controller.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/dates.dart';
import 'astryx_widgets.dart';

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
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    if (controller.messages.isEmpty) {
      return Center(
        child: Text(
          'This folder is empty.',
          style: AstryxText.body(c.textSecondary),
        ),
      );
    }

    return ListView.separated(
      itemCount: controller.messages.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: c.border),
      itemBuilder: (BuildContext context, int index) {
        final MessageSummary summary = controller.messages[index];
        final bool selected = controller.openSummary?.uid == summary.uid;
        return MessageTile(
          summary: summary,
          selected: selected,
          onTap: () => context.read<MailController>().open(summary),
        );
      },
    );
  }
}

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
        AstryxSpace.s4,
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
    required this.selected,
    required this.onTap,
  });

  final MessageSummary summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final bool unread = !summary.isSeen;

    return Material(
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
              InitialsAvatar(
                initials: summary.initials,
                seed: summary.fromEmail.isEmpty
                    ? summary.fromName
                    : summary.fromEmail,
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
                                : AstryxText.body(c.textPrimary),
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
                    Text(
                      summary.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: unread
                          ? AstryxText.body(c.textPrimary)
                          : AstryxText.body(c.textSecondary),
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
    );
  }
}
