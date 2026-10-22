import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart'
    show CupertinoSliverRefreshControl, RefreshIndicatorMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../models/message_group.dart';
import '../util/ace_snack.dart';
import '../models/message_sort.dart';
import '../models/message_summary.dart';
import '../models/swipe_action.dart';
import '../state/mail_controller.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/dates.dart';
import 'astryx_widgets.dart';
import 'avatar.dart';
import 'confirm_exit.dart';
import 'settings_group.dart';
import 'skeleton.dart';
import 'swipe_action.dart';
import 'ace_icon_view.dart';

/// The message list: a row of filter and sort chips, then the messages.
///
/// The title lives in the app bar, so the space here goes to the controls
/// instead of repeating the folder name.
class MessageListPanel extends StatelessWidget {
  const MessageListPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final MailController controller = context.watch<MailController>();

    return Container(
      color: c.backgroundBody,
      // Fade through when the folder changes, so the list reads as a new
      // mailbox arriving rather than the same rows being swapped underneath.
      child: AnimatedSwitcher(
        duration: AstryxMotion.of(const Duration(milliseconds: 220)),
        switchInCurve: AstryxMotion.emphasizedDecelerate,
        switchOutCurve: Curves.easeIn,
        child: CustomScrollView(
        key: ValueKey<String>(controller.selectedFolder?.path ?? ''),
        // Bouncing, not the platform default. On Android the default physics
        // *clamps*: the list stops dead at the top instead of overscrolling, so
        // the refresh control never reaches its trigger distance and a pull
        // does nothing at all. Bouncing overscrolls on every platform, which is
        // what makes the pull work.
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: <Widget>[
          CupertinoSliverRefreshControl(
            onRefresh: () => context.read<MailController>().refreshMessages(),
            refreshTriggerPullDistance: 110,
            refreshIndicatorExtent: 58,
            builder: _refreshIndicator,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AstryxSpace.s2)),
          SliverToBoxAdapter(child: _ChipRow(controller: controller)),
          const SliverToBoxAdapter(child: SizedBox(height: AstryxSpace.s2)),
          ..._slivers(context, controller),
        ],
        ),
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

  List<Widget> _slivers(BuildContext context, MailController controller) {
    final AstryxColors c = context.astryx;

    if (controller.loadingMessages) {
      // Rows shaped like the ones coming, rather than a spinner on an empty
      // screen.
      return <Widget>[
        SliverToBoxAdapter(
          child: MessageListSkeleton(
            avatarSize: context.watch<Preferences>().density.avatarSize,
          ),
        ),
      ];
    }

    final List<MessageSummary> rows = controller.visibleMessages;

    // A failed fetch used to look like an empty folder. Say what happened.
    final String? error = controller.sessionError;
    if (rows.isEmpty && error != null && controller.messages.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Centred(
            icon: AceIcons.error,
            iconColor: c.error,
            message: error,
            action: AceButton(
              label: 'Try again',
              icon: AceIcons.refresh,
              variant: AceButtonVariant.tonal,
              onPressed: () => context.read<MailController>().refreshMessages(),
            ),
          ),
        ),
      ];
    }

    if (rows.isEmpty) {
      // Still fetching: the skeleton, not "this folder is empty". Saying a
      // folder is empty before it has been read is the app telling a story it
      // does not know the end of.
      if (controller.loadingMessages) {
        return <Widget>[const MessageListSkeleton()];
      }
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Centred(
            icon: controller.filter == MessageFilter.all
                ? AceIcons.mailOpen
                : AceIcons.filterOff,
            iconColor: c.iconDisabled,
            message: _emptyMessage(controller),
          ),
        ),
      ];
    }

    final Preferences prefs = context.watch<Preferences>();

    // Headings and rows in one list, so the sliver stays lazy. A String is a
    // heading; a summary is a row.
    final List<Object> items = <Object>[];
    if (prefs.groupByDate) {
      for (final MessageGroup group in groupByDate(rows)) {
        items.add(group.label);
        items.addAll(group.messages);
      }
    } else {
      items.addAll(rows);
    }

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s3),
        sliver: SliverList.builder(
          itemCount: items.length,
          // Each row already brings its own RepaintBoundary, so the sliver does
          // not need to add a second one — and a row that scrolls off does not
          // need keeping alive, because it has no state worth keeping.
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
          itemBuilder: (BuildContext context, int index) {
            final Object item = items[index];
            if (item is String) return _GroupHeading(label: item);
            final MessageSummary summary = item as MessageSummary;
            return RepaintBoundary(
              // Each row paints on its own layer: scrolling a long list then
              // repaints the rows that move rather than the whole list.
              child: AceSwipeTile(
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
                picked: controller.isSelected(summary.uid),
                selecting: controller.selecting,
                onLongPress: () =>
                    context.read<MailController>().toggleSelect(summary.uid),
                onTap: () {
                  final MailController mail = context.read<MailController>();
                  // While picking, a tap picks; it does not open a message the
                  // reader did not ask for.
                  if (mail.selecting) {
                    mail.toggleSelect(summary.uid);
                  } else {
                    mail.open(summary);
                  }
                },
              ),
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
                      icon: AceIcons.expandMore,
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

  String _emptyMessage(MailController controller) {
    if (controller.searchQuery != null) {
      return 'Nothing matched “${controller.searchQuery}”.';
    }
    if (controller.filter != MessageFilter.all) {
      return switch (controller.filter) {
        MessageFilter.unread => 'Everything here has been read.',
        MessageFilter.flagged => 'Nothing here is flagged.',
        MessageFilter.codes => 'No codes in this page.',
        MessageFilter.all => 'This folder is empty.',
      };
    }
    return 'This folder is empty.';
  }

  Future<void> _applySwipe(
    BuildContext context,
    MessageSummary summary,
    SwipeAction action,
  ) async {
    final MailController controller = context.read<MailController>();
    final Preferences prefs = context.read<Preferences>();
    final Duration window = prefs.undoWindow.duration;

    // Where it was, so an undo can put it back there rather than in the inbox.
    final String? from = controller.currentFolderPath;

    switch (action) {
      case SwipeAction.archive:
        // Archiving is reversible, so it gets an undo on the bar rather than a
        // question — unless the user has asked for the question as well.
        if (prefs.confirmArchive) {
          final bool go = await confirmArchive(context);
          // The dialog is an await, so the row may be gone by the time it
          // answers; nothing after this may touch the context unguarded.
          if (!go || !context.mounted) return;
        }
        unawaited(controller.archive(summary));
        if (from != null) {
          AceSnack.undo(
            context,
            'Archived.',
            duration: window,
            onUndo: () => controller.undoDelete(summary, from),
          );
        } else {
          AceSnack.show(context, 'Archived.');
        }
      case SwipeAction.trash:
        // The mistake is one flick away, so the way back is on the bar.
        unawaited(controller.delete(summary));
        if (from != null) {
          AceSnack.undo(
            context,
            'Moved to trash.',
            duration: window,
            onUndo: () => controller.undoDelete(summary, from),
          );
        } else {
          AceSnack.show(context, 'Moved to trash.');
        }
      case SwipeAction.toggleRead:
        final bool wasSeen = summary.isSeen;
        unawaited(controller.toggleRead(summary));
        AceSnack.undo(
          context,
          wasSeen ? 'Marked unread.' : 'Marked read.',
          duration: window,
          onUndo: () => controller.toggleRead(summary),
        );
      case SwipeAction.flag:
        unawaited(controller.toggleFlag(summary));
        AceSnack.show(context, summary.isFlagged ? 'Star removed.' : 'Starred.');
      case SwipeAction.none:
        break;
    }
  }

}

/// Filter chips, then the sort. One scrollable row, so it never wraps into a
/// block of controls that pushes the mail off the screen.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.controller});

  final MailController controller;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s3),
        children: <Widget>[
          for (final MessageFilter filter in MessageFilter.values) ...<Widget>[
            AceChip(
              label: filter.label,
              selected: controller.filter == filter,
              onTap: () => context.read<MailController>().setFilter(filter),
            ),
            const SizedBox(width: AstryxSpace.s2),
          ],
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(
              horizontal: AstryxSpace.s2,
              vertical: AstryxSpace.s2,
            ),
            color: c.border,
          ),
          AceChip(
            label: controller.sort.label,
            icon: AceIcons.sort,
            onTap: () => _chooseSort(context),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseSort(BuildContext context) async {
    final Preferences prefs = context.read<Preferences>();
    final MessageSort? chosen = await showModalBottomSheet<MessageSort>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AstryxSpace.s5,
                AstryxSpace.s2,
                AstryxSpace.s5,
                AstryxSpace.s3,
              ),
              child: Text(
                'Sort by',
                style: AstryxText.heading3(sheetContext.astryx.textPrimary),
              ),
            ),
            for (final MessageSort sort in MessageSort.values)
              SettingsRow(
                icon: _sortIcon(sort),
                title: sort.label,
                trailing: sort == prefs.messageSort
                    ? AceIconView(icon: 
                        AceIcons.check,
                        size: 20,
                        color: sheetContext.astryx.accent,
                      )
                    : null,
                onTap: () {
                  prefs.setMessageSort(sort);
                  Navigator.of(sheetContext).pop();
                },
              ),
            const SizedBox(height: AstryxSpace.s3),
          ],
        ),
      ),
    );
    if (chosen != null) await prefs.setMessageSort(chosen);
  }

  static AceIcon _sortIcon(MessageSort sort) => switch (sort) {
        MessageSort.newest => AceIcons.sortNewest,
        MessageSort.oldest => AceIcons.sortOldest,
        MessageSort.sender => AceIcons.person,
        MessageSort.subject => AceIcons.sortSubject,
        MessageSort.unread => AceIcons.mailUnread,
      };
}

class _Centred extends StatelessWidget {
  const _Centred({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.action,
  });

  final AceIcon icon;
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
          AceIconView(icon: icon, size: 32, color: iconColor),
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

/// One message row. Springs on press, morphs its corners, states unread with
/// weight and a dot rather than a colour change alone, and lifts a one-time
/// code to where it can be read and copied without opening the message.
class MessageTile extends StatelessWidget {
  const MessageTile({
    super.key,
    required this.summary,
    required this.index,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.picked = false,
    this.selecting = false,
  });

  final MessageSummary summary;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  /// Long-press picks a message out; a second one starts a selection.
  final VoidCallback? onLongPress;

  /// Whether this row is one of the picked ones.
  final bool picked;

  /// Whether the list is in selection mode at all.
  final bool selecting;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final ListDensity density = context.watch<Preferences>().density;
    final bool unread = !summary.isSeen;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      // The rows arrive in a short cascade, later rows a beat behind the first.
      // Zeroed under reduce motion, where the rows simply appear.
      duration: AstryxMotion.of(
        Duration(milliseconds: 260 + (index.clamp(0, 8) * 28)),
      ),
      curve: AstryxMotion.emphasizedDecelerate,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(0, (1 - t) * 10), child: child),
      ),
      child: AceSpringy(
        onTap: onTap,
        onLongPress: onLongPress,
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
                // A card, not a bare row: a surface of its own, a corner, and a
                // little air around it. Rows on a flat page run together and
                // each one is harder to pick out than the last.
                color: picked
                    ? c.accentMuted
                    : (selected
                        ? c.accentMuted
                        : (hover ? c.surfaceHighest : c.backgroundCard)),
                borderRadius: shape,
                border: picked
                    ? Border.all(color: c.accent, width: 1.5)
                    : Border.all(color: c.border.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // In selection mode the picture becomes the tick, so the
                  // gesture that started it is visible where it happened.
                  if (selecting)
                    Padding(
                      padding: const EdgeInsets.only(right: AstryxSpace.s2),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: picked
                            ? HugeIcon(
                                key: const ValueKey<String>('on'),
                                icon: AceIcons.checkCircle,
                                size: density.avatarSize,
                                color: c.accent,
                              )
                            : SizedBox(
                                key: const ValueKey<String>('off'),
                                width: density.avatarSize,
                                height: density.avatarSize,
                                child: Center(
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: c.border, width: 1.5),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    )
                  else
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
                              AceIconView(icon: 
                                AceIcons.star,
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
                        if (summary.otp != null) ...<Widget>[
                          const SizedBox(height: AstryxSpace.s1_5),
                          _OtpChip(code: summary.otp!),
                        ],
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

/// A one-time code, one tap from the clipboard. Shown in the list so the code
/// can be used without opening the mail, which is the entire point of it.
class _OtpChip extends StatelessWidget {
  const _OtpChip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return AceSpringy(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: code));
        if (!context.mounted) return;
        AceSnack.show(context, 'Code $code copied');
      },
      semanticLabel: 'Copy code $code',
      builder: (BuildContext context, double press, bool hover) {
        final double t = press.clamp(0.0, 1.0);
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AstryxSpace.s3,
            vertical: AstryxSpace.s1,
          ),
          decoration: BoxDecoration(
            color: c.accentMuted,
            borderRadius: BorderRadius.circular(
              lerpDouble(AstryxRadius.full, AstryxRadius.element, t)!,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AceIconView(icon: 
                AceIcons.password,
                size: 14,
                color: c.onAccentMuted,
              ),
              const SizedBox(width: AstryxSpace.s2),
              Text(
                code,
                style: AstryxText.bodyStrong(c.onAccentMuted).copyWith(
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(width: AstryxSpace.s2),
              AceIconView(icon: 
                AceIcons.copy,
                size: 13,
                color: c.onAccentMuted,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A small heading over a run of messages, the way the settings screen heads a
/// section.
class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AstryxSpace.s3,
        AstryxSpace.s5,
        AstryxSpace.s3,
        AstryxSpace.s2,
      ),
      child: Text(
        label.toUpperCase(),
        style: AstryxText.label(c.textSecondary).copyWith(letterSpacing: 1.1),
      ),
    );
  }
}
