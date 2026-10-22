import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/accents.dart';
import '../data/app_info.dart';
import '../data/preferences.dart';
import '../services/notification_setup.dart';
import '../models/swipe_action.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/routes.dart';
import '../widgets/about_dialog.dart';
import '../widgets/account_sheet.dart';
import '../widgets/astryx_widgets.dart';
import '../widgets/settings_group.dart';
import 'tutorial_screen.dart';
import '../widgets/ace_icon_view.dart';

/// The app's settings. Every row here changes something real.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final Preferences prefs = context.watch<Preferences>();

    return Scaffold(
      backgroundColor: c.backgroundBody,
      appBar: AppBar(
        title: Text('Settings', style: AstryxText.heading3(c.textPrimary)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AstryxSpace.s8),
          children: <Widget>[
            SettingsSection(
              title: 'Account',
              children: <Widget>[
                SettingsRow(
                  icon: AceIcons.at,
                  title: 'Manage accounts',
                  subtitle: 'Add, switch or remove accounts',
                  onTap: () => showAccountSheet(context),
                ),
                SettingsSwitchRow(
                  icon: AceIcons.reconnect,
                  title: 'Reconnect automatically',
                  subtitle: 'Retry once, after a backoff, when the connection '
                      'drops rather than the command failing.',
                  value: prefs.autoReconnect,
                  onChanged: prefs.setAutoReconnect,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.account,
                  title: 'Sender pictures',
                  subtitle: 'Off by default. Turning this on sends a hash of '
                      'every sender\'s address to gravatar.com, which is not '
                      'anonymous.',
                  value: prefs.showAvatars,
                  onChanged: prefs.setShowAvatars,
                ),
              ],
            ),
            SettingsSection(
              title: 'Reading',
              children: <Widget>[
                SettingsSwitchRow(
                  icon: AceIcons.mailOpen,
                  title: 'Mark as read when opened',
                  subtitle: prefs.markAsReadOnOpen
                      ? 'Opening a message sets it read on the server.'
                      : 'Messages keep their unread state until you say so.',
                  value: prefs.markAsReadOnOpen,
                  onChanged: prefs.setMarkAsReadOnOpen,
                ),
                SettingsRow(
                  icon: AceIcons.news,
                  title: 'Message view',
                  subtitle: prefs.messageView == MessageView.formatted
                      ? 'Show the HTML version when the sender provided one.'
                      : 'Show the plain-text version.',
                  value: prefs.messageView.label,
                  onTap: () async {
                    final MessageView? chosen =
                        await showChoiceSheet<MessageView>(
                      context,
                      title: 'Message view',
                      current: prefs.messageView,
                      choices: <SettingsChoice<MessageView>>[
                        for (final MessageView view in MessageView.values)
                          SettingsChoice<MessageView>(view, view.label),
                      ],
                    );
                    if (chosen != null) await prefs.setMessageView(chosen);
                  },
                ),
                SettingsRow(
                  icon: AceIcons.folder,
                  title: 'Messages per page',
                  subtitle: 'How many load before "Load older messages".',
                  value: prefs.pageSize.label,
                  onTap: () async {
                    final PageSize? chosen = await showChoiceSheet<PageSize>(
                      context,
                      title: 'Messages per page',
                      current: prefs.pageSize,
                      choices: <SettingsChoice<PageSize>>[
                        for (final PageSize size in PageSize.values)
                          SettingsChoice<PageSize>(size, size.label),
                      ],
                    );
                    if (chosen != null) await prefs.setPageSize(chosen);
                  },
                ),
                SettingsSwitchRow(
                  icon: AceIcons.headers,
                  title: 'Show raw headers',
                  subtitle: 'Show the message headers as the server sent them, '
                      'at the foot of the message.',
                  value: prefs.showRawHeaders,
                  onChanged: prefs.setShowRawHeaders,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.check,
                  title: 'Vibration',
                  subtitle: 'A tick when a swipe arms, a knock when something '
                      'is about to be thrown away.',
                  value: prefs.haptics,
                  onChanged: prefs.setHaptics,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.mailUnread,
                  title: 'Notify me about new mail',
                  subtitle: 'Checked in the background about every fifteen '
                      'minutes — Android\u2019s floor for work like this. '
                      'Nothing is sent anywhere: the check talks to your '
                      'provider and tells you.',
                  value: prefs.notifyNewMail,
                  onChanged: (bool value) async {
                    final bool on =
                        await NotificationSetup.apply(enabled: value);
                    // The switch shows what happened, not what was asked for:
                    // a refused permission must not look like it worked.
                    await prefs.setNotifyNewMail(on);
                  },
                ),
                SettingsSwitchRow(
                  icon: AceIcons.openInNew,
                  title: 'Ask before opening links',
                  subtitle: 'A link\u2019s text is the sender\u2019s, and need '
                      'not be what the link does. This shows the address first.',
                  value: prefs.warnExternalLinks,
                  onChanged: prefs.setWarnExternalLinks,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.warning,
                  title: 'Warn on an empty subject',
                  subtitle: 'Ask before sending a message with no subject.',
                  value: prefs.warnEmptySubject,
                  onChanged: prefs.setWarnEmptySubject,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.image,
                  title: 'Load images in messages',
                  subtitle: 'Off by default: fetching an image tells the '
                      'sender\u2019s server the message was opened.',
                  value: prefs.loadRemoteImages,
                  onChanged: prefs.setLoadRemoteImages,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.password,
                  title: 'Show one-time codes',
                  subtitle: 'Pick codes out of messages and show them in the '
                      'list, so they can be used without opening the mail.',
                  value: prefs.detectCodes,
                  onChanged: prefs.setDetectCodes,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.trash,
                  title: 'Ask before deleting',
                  subtitle: 'A permanent delete always asks, whatever this is '
                      'set to.',
                  value: prefs.confirmDelete,
                  onChanged: prefs.setConfirmDelete,
                ),
                SettingsRow(
                  icon: AceIcons.signature,
                  title: 'Signature',
                  subtitle: prefs.signature.isEmpty
                      ? 'Not set'
                      : 'Added to new messages',
                  value: prefs.signature.isEmpty ? 'None' : 'Set',
                  onTap: () => _editSignature(context, prefs),
                ),
              ],
            ),
            SettingsSection(
              title: 'Sending',
              children: <Widget>[
                SettingsSwitchRow(
                  icon: AceIcons.at,
                  title: 'Blind-copy yourself',
                  subtitle: 'Send every message with a hidden copy to the '
                      'account it goes from, so a sent message reaches your own '
                      'inbox and not only the Sent folder.',
                  value: prefs.bccSelf,
                  onChanged: prefs.setBccSelf,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.reply,
                  title: 'Quote the original in replies',
                  subtitle: prefs.quoteReplies
                      ? 'A reply carries the message it answers beneath it.'
                      : 'A reply starts empty, with no quoted original.',
                  value: prefs.quoteReplies,
                  onChanged: prefs.setQuoteReplies,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.signature,
                  title: 'Signature on replies',
                  subtitle: 'New messages always carry the signature; this '
                      'adds it to replies too, above the quoted text.',
                  value: prefs.signatureOnReplies,
                  onChanged: prefs.setSignatureOnReplies,
                ),
              ],
            ),
            SettingsSection(
              title: 'Gestures',
              children: <Widget>[
                SettingsRow(
                  icon: AceIcons.swipeRight,
                  title: 'Swipe right',
                  subtitle: 'Across a message in the list',
                  value: prefs.swipeStart.label,
                  onTap: () => _chooseSwipe(context, prefs, start: true),
                ),
                SettingsRow(
                  icon: AceIcons.swipeLeft,
                  title: 'Swipe left',
                  subtitle: 'Across a message in the list',
                  value: prefs.swipeEnd.label,
                  onTap: () => _chooseSwipe(context, prefs, start: false),
                ),
                SettingsSwitchRow(
                  icon: AceIcons.archive,
                  title: 'Ask before archiving',
                  subtitle: 'A confirmation before a message leaves the inbox '
                      'for Archive.',
                  value: prefs.confirmArchive,
                  onChanged: prefs.setConfirmArchive,
                ),
                SettingsRow(
                  icon: AceIcons.restore,
                  title: 'Undo window',
                  subtitle: 'How long an undo stays on the bar after a swipe.',
                  value: prefs.undoWindow.label,
                  onTap: () async {
                    final UndoWindow? chosen =
                        await showChoiceSheet<UndoWindow>(
                      context,
                      title: 'Undo window',
                      current: prefs.undoWindow,
                      choices: <SettingsChoice<UndoWindow>>[
                        for (final UndoWindow window in UndoWindow.values)
                          SettingsChoice<UndoWindow>(window, window.label),
                      ],
                    );
                    if (chosen != null) await prefs.setUndoWindow(chosen);
                  },
                ),
              ],
            ),
            SettingsSection(
              title: 'Appearance',
              children: <Widget>[
                SettingsRow(
                  icon: AceIcons.list,
                  title: 'Preview lines',
                  value: prefs.previewLines == 0
                      ? 'None'
                      : '${prefs.previewLines}',
                  onTap: () async {
                    final int? lines = await showChoiceSheet<int>(
                      context,
                      title: 'Preview lines',
                      current: prefs.previewLines,
                      choices: <SettingsChoice<int>>[
                        for (final int n in <int>[0, 1, 2, 3])
                          SettingsChoice<int>(
                            n,
                            n == 0 ? 'None' : '$n line${n == 1 ? '' : 's'}',
                          ),
                      ],
                    );
                    if (lines != null) await prefs.setPreviewLines(lines);
                  },
                ),
                SettingsSwitchRow(
                  icon: AceIcons.list,
                  title: 'Group by date',
                  subtitle: 'Headings for Today, Yesterday and so on. Off is '
                      'one undivided run of messages.',
                  value: prefs.groupByDate,
                  onChanged: prefs.setGroupByDate,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.folder,
                  title: 'Unread counts on folders',
                  subtitle: 'How much is waiting, on the folder itself.',
                  value: prefs.showFolderCounts,
                  onChanged: prefs.setShowFolderCounts,
                ),
                SettingsSwitchRow(
                  icon: AceIcons.brightness,
                  title: 'True black (OLED)',
                  subtitle: 'The dark theme goes to #000000. A pixel that is off '
                      'draws no power, and on an OLED panel the difference is '
                      'visible at the edges.',
                  value: prefs.oled,
                  onChanged: prefs.setOled,
                ),
                SettingsRow(
                  icon: AceIcons.brightness,
                  title: 'Theme',
                  value: prefs.themeMode.label,
                  onTap: () async {
                    // OLED is a property of the dark theme, so it belongs in
                    // the sheet where the dark theme is chosen rather than on
                    // the list beside it.
                    final AceThemeMode? chosen =
                        await showChoiceSheet<AceThemeMode>(
                      context,
                      title: 'Theme',
                      current: prefs.themeMode,
                      choices: <SettingsChoice<AceThemeMode>>[
                        for (final AceThemeMode mode in AceThemeMode.values)
                          SettingsChoice<AceThemeMode>(mode, mode.label),
                      ],
                    );
                    if (chosen != null) await prefs.setThemeMode(chosen);
                  },
                ),
                SettingsSwitchRow(
                  icon: AceIcons.brightness,
                  title: 'Use my system colours',
                  subtitle: 'Take the accent from the device — Android\u2019s '
                      'wallpaper colours, and the equivalent elsewhere. The '
                      'whole theme follows, surfaces included.',
                  value: prefs.useDynamicColour,
                  onChanged: prefs.setUseDynamicColour,
                ),
                SettingsRow(
                  icon: AceIcons.palette,
                  title: 'Accent',
                  value: prefs.accent.label,
                  trailing: _AccentSwatch(accent: prefs.accent),
                  onTap: () => _chooseAccent(context, prefs),
                ),
                SettingsRow(
                  icon: AceIcons.density,
                  title: 'List density',
                  value: prefs.density.label,
                  onTap: () async {
                    final ListDensity? chosen =
                        await showChoiceSheet<ListDensity>(
                      context,
                      title: 'List density',
                      current: prefs.density,
                      choices: <SettingsChoice<ListDensity>>[
                        for (final ListDensity density in ListDensity.values)
                          SettingsChoice<ListDensity>(
                            density,
                            density.label,
                            description: density == ListDensity.compact
                                ? 'More messages on screen'
                                : null,
                          ),
                      ],
                    );
                    if (chosen != null) await prefs.setDensity(chosen);
                  },
                ),
                SettingsRow(
                  icon: AceIcons.textSize,
                  title: 'Text size',
                  value: prefs.textSize.label,
                  onTap: () async {
                    final AceTextSize? chosen = await showChoiceSheet<AceTextSize>(
                      context,
                      title: 'Text size',
                      current: prefs.textSize,
                      choices: <SettingsChoice<AceTextSize>>[
                        for (final AceTextSize size in AceTextSize.values)
                          SettingsChoice<AceTextSize>(
                            size,
                            size.label,
                            description: size == AceTextSize.medium
                                ? 'Follows your device setting'
                                : null,
                          ),
                      ],
                    );
                    if (chosen != null) await prefs.setTextSize(chosen);
                  },
                ),
                SettingsSwitchRow(
                  icon: AceIcons.logout,
                  title: 'Ask before exiting',
                  subtitle: 'Show a confirmation before the app closes.',
                  value: prefs.confirmExit,
                  onChanged: prefs.setConfirmExit,
                ),
              ],
            ),
            SettingsSection(
              title: 'Accessibility',
              children: <Widget>[
                SettingsSwitchRow(
                  icon: AceIcons.visibility,
                  title: 'Reduce motion',
                  subtitle: 'Transitions stop moving rather than moving faster. '
                      'The loading indicator still turns, because a still one '
                      'looks like a hung app.',
                  value: prefs.reduceMotion,
                  onChanged: prefs.setReduceMotion,
                ),
              ],
            ),
            SettingsSection(
              title: 'Support',
              children: <Widget>[
                SettingsRow(
                  icon: AceIcons.help,
                  title: 'How to sign in',
                  subtitle: 'Step-by-step, including app passwords',
                  onTap: () => Navigator.of(context).push(
                    aceRoute(const TutorialScreen()),
                  ),
                ),
                SettingsRow(
                  icon: AceIcons.info,
                  title: 'About Ace Mail',
                  // Read from the installed package, so it cannot drift from
                  // what is actually on the device.
                  value: AppInfo.label,
                  onTap: () => showAceAbout(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Ten accents, as a grid of swatches — a colour is easier to pick by eye
  /// than by name.
  Future<void> _chooseAccent(BuildContext context, Preferences prefs) async {
    final AceAccent? chosen = await showModalBottomSheet<AceAccent>(
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
                0,
                AstryxSpace.s5,
                AstryxSpace.s4,
              ),
              child: Text(
                'Accent',
                style: AstryxText.heading3(sheetContext.astryx.textPrimary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s5),
              child: Wrap(
                spacing: AstryxSpace.s3,
                runSpacing: AstryxSpace.s3,
                children: <Widget>[
                  for (final AceAccent accent in AceAccent.values)
                    AceSpringy(
                      onTap: () => Navigator.of(sheetContext).pop(accent),
                      semanticLabel: accent.label,
                      builder: (BuildContext context, double press, bool hover) {
                        final bool selected = accent == prefs.accent;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: AstryxMotion.emphasizedDecelerate,
                          width: 52 + press * -4,
                          height: 52 + press * -4,
                          decoration: BoxDecoration(
                            color: accent.seed,
                            borderRadius: BorderRadius.circular(
                              selected
                                  ? AstryxRadius.container
                                  : AstryxRadius.full,
                            ),
                          ),
                          child: selected
                              ? AceIconView(icon: 
                                  AceIcons.check,
                                  color: contrastingInk(accent.seed),
                                )
                              : null,
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: AstryxSpace.s6),
          ],
        ),
      ),
    );
    if (chosen != null) await prefs.setAccent(chosen);
  }

  Future<void> _chooseSwipe(
    BuildContext context,
    Preferences prefs, {
    required bool start,
  }) async {
    final SwipeAction? chosen = await showChoiceSheet<SwipeAction>(
      context,
      title: start ? 'Swipe right' : 'Swipe left',
      current: start ? prefs.swipeStart : prefs.swipeEnd,
      choices: <SettingsChoice<SwipeAction>>[
        for (final SwipeAction action in SwipeAction.values)
          SettingsChoice<SwipeAction>(
            action,
            action.label,
            description: switch (action) {
              SwipeAction.archive => 'Move it out of the inbox',
              SwipeAction.trash => 'Move it to Trash',
              SwipeAction.toggleRead => 'Without opening it',
              SwipeAction.flag => 'Star it, or clear the star',
              SwipeAction.none => 'Leave this direction alone',
            },
          ),
      ],
    );
    if (chosen == null) return;
    if (start) {
      await prefs.setSwipeStart(chosen);
    } else {
      await prefs.setSwipeEnd(chosen);
    }
  }

  Future<void> _editSignature(
    BuildContext context,
    Preferences prefs,
  ) async {
    final TextEditingController controller =
        TextEditingController(text: prefs.signature);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Signature'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          decoration: const InputDecoration(
            hintText: 'Sent from Ace Mail',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) await prefs.setSignature(result);
  }

}

/// The current accent, as a swatch in the row.
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({required this.accent});

  final AceAccent accent;

  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: accent.seed,
          shape: BoxShape.circle,
        ),
      );
}
