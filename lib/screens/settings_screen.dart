import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/accents.dart';
import '../data/app_info.dart';
import '../data/preferences.dart';
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
              ],
            ),
            SettingsSection(
              title: 'Appearance',
              children: <Widget>[
                SettingsRow(
                  icon: AceIcons.brightness,
                  title: 'Theme',
                  value: prefs.themeMode.label,
                  onTap: () async {
                    final AceThemeMode? chosen = await showChoiceSheet<AceThemeMode>(
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
