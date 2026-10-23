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
          // The rows carry uid keys, so a rebuild can find the element for a
          // message it already built instead of building it again. Without
          // this, anything that shifts the list re-creates every row below it.
          findChildIndexCallback: (Key key) {
            if (key is! ValueKey<int>) return null;
            final int uid = key.value;
            final int index = items.indexWhere(
              (Object item) => item is MessageSummary && item.uid == uid,
            );
            return index == -1 ? null : index;
          },
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
                density: prefs.density,
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
/// Sort and filter, in one sheet.
///
/// The chips used to sit above the list, always on screen, spending a row of
/// the list's height on a choice most people make once. They are behind a
/// button now — and the button says when something other than the default is in
/// force, which the chips did not.
Future<void> showSortSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      final AstryxColors c = sheetContext.astryx;
      final MailController controller = sheetContext.watch<MailController>();
      final Preferences prefs = sheetContext.watch<Preferences>();

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AstryxSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AstryxSpace.s5,
                  0,
                  AstryxSpace.s5,
                  AstryxSpace.s4,
                ),
                child: Text(
                  'Sort & filter',
                  style: AstryxText.heading3(c.textPrimary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s5),
                child: Text('Show', style: AstryxText.label(c.textSecondary)),
              ),
              const SizedBox(height: AstryxSpace.s2),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s5),
                child: Row(
                  children: <Widget>[
                    for (final MessageFilter filter
                        in MessageFilter.values) ...<Widget>[
                      AceChip(
                        label: filter.label,
                        selected: controller.filter == filter,
                        onTap: () => sheetContext
                            .read<MailController>()
                            .setFilter(filter),
                      ),
                      const SizedBox(width: AstryxSpace.s2),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AstryxSpace.s4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s5),
                child: Text('Order', style: AstryxText.label(c.textSecondary)),
              ),
              const SizedBox(height: AstryxSpace.s1),
              for (final MessageSort sort in MessageSort.values)
                SettingsRow(
                  icon: AceIcons.sort,
                  title: sort.label,
                  trailing: prefs.messageSort == sort
                      ? AceIconView(
                          icon: AceIcons.check,
                          size: 20,
                          color: c.accent,
                        )
                      : null,
                  onTap: () =>
                      sheetContext.read<Preferences>().setMessageSort(sort),
                ),
              if (controller.filter != MessageFilter.all ||
                  prefs.messageSort != MessageSort.newest)
                SettingsRow(
                  icon: AceIcons.filterOff,
                  title: 'Back to the default',
                  subtitle: 'Newest first, everything shown.',
                  onTap: () {
                    sheetContext
                        .read<MailController>()
                        .setFilter(MessageFilter.all);
                    sheetContext
                        .read<Preferences>()
                        .setMessageSort(MessageSort.newest);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
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
    required this.density,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.picked = false,
    this.selecting = false,
  });

  final MessageSummary summary;
  final int index;

  /// Passed in rather than read here: a row that watches the preferences is a
  /// dependency per row, and every settings change then rebuilds the whole list
  /// once per row instead of once.
  final ListDensity density;
  final bool selected;
  final VoidCallback onTap;

  /// Long-press picks a message out; a second one starts a selection.
  final VoidCallback? onLongPress;

  /// Whether this row is one of the picked ones.
  final bool picked;

  /// Whether the list is in selection mode at all.
  final bool selecting;

  /// The unread mark, as a width. Zero for a message already read, so the
  /// layout does not move — the border is always there, it is just invisible.
  static const double _markWidth = 3;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final ListDensity density = this.density;
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
              decoration: BoxDecoration(
                // A card, not a bare row: a surface of its own, a corner, and a
                // little air around it. Rows on a flat page run together and
                // each one is harder to pick out than the last.
                color: picked || selected
                    ? c.accentMuted
                    : (hover ? c.surfaceHighest : c.backgroundCard),
                borderRadius: shape,
                // Uniform, because a rounded border in Flutter has to be: a
                // different colour per side is refused when it is painted. The
                // unread mark is drawn over the edge instead of into it.
                border: Border.all(color: c.border.withValues(alpha: 0.5)),
              ),
              child: ClipRRect(
                // So the mark below follows the card's corner rather than
                // squaring it off.
                borderRadius: shape,
                child: Stack(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        AstryxSpace.s3,
                        density.verticalPadding,
                        AstryxSpace.s3,
                        density.verticalPadding,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // In selection mode the picture becomes the tick, so
                          // the gesture that started it is visible where it
                          // happened.
                          if (selecting)
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: AstryxSpace.s2),
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
                                              border: Border.all(
                                                color: c.border,
                                                width: 1.5,
                                              ),
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
                                // Who and when, on one line: the two things a
                                // list is scanned for. The star sits with the
                                // date rather than in front of the subject, so
                                // the subject keeps the whole width it needs.
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
                                    if (summary.isFlagged) ...<Widget>[
                                      const SizedBox(width: AstryxSpace.s1_5),
                                      // A one-shot pop as the row is built with
                                      // a star on it — which is the moment a
                                      // message was just flagged, or a folder
                                      // of flagged mail opened.
                                      TweenAnimationBuilder<double>(
                                        tween: Tween<double>(begin: 0.4, end: 1),
                                        duration: AstryxMotion.of(
                                          const Duration(milliseconds: 220),
                                        ),
                                        curve: AstryxMotion.emphasizedDecelerate,
                                        builder: (
                                          BuildContext context,
                                          double t,
                                          Widget? child,
                                        ) =>
                                            Transform.scale(
                                          scale: t,
                                          child: child,
                                        ),
                                        child: AceIconView(
                                          icon: AceIcons.star,
                                          size: 14,
                                          color: c.tertiary,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: AstryxSpace.s2),
                                    Text(
                                      formatListDate(summary.date),
                                      style: AstryxText.supporting(
                                        c.textSecondary,
                                      ),
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
                                if (summary.otp != null) ...<Widget>[
                                  const SizedBox(height: AstryxSpace.s1_5),
                                  _OtpChip(code: summary.otp!),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unread)
                      // Unread, as a strip down the edge. It is the one thing
                      // worth seeing at a glance, and it says it without
                      // spending a line of text or a dot in the corner. Drawn
                      // over the card rather than beside the content, so an
                      // unread row and a read one are laid out identically.
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: AnimatedContainer(
                          duration: AstryxMotion.of(
                            const Duration(milliseconds: 180),
                          ),
                          width: _markWidth,
                          color: c.accent,
                        ),
                      ),
                  ],
                ),
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
