import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_info.dart';
import '../data/preferences.dart';
import '../models/swipe_action.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/routes.dart';
import '../widgets/account_sheet.dart';
import '../widgets/settings_group.dart';
import 'tutorial_screen.dart';

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
                  icon: Icons.alternate_email_rounded,
                  title: 'Manage accounts',
                  subtitle: 'Add, switch or remove accounts',
                  onTap: () => showAccountSheet(context),
                ),
                SettingsSwitchRow(
                  icon: Icons.sync_rounded,
                  title: 'Reconnect automatically',
                  subtitle: 'Retry once, after a backoff, when the connection '
                      'drops rather than the command failing.',
                  value: prefs.autoReconnect,
                  onChanged: prefs.setAutoReconnect,
                ),
                SettingsSwitchRow(
                  icon: Icons.account_circle_outlined,
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
                  icon: Icons.mark_email_read_outlined,
                  title: 'Mark as read when opened',
                  subtitle: prefs.markAsReadOnOpen
                      ? 'Opening a message sets it read on the server.'
                      : 'Messages keep their unread state until you say so.',
                  value: prefs.markAsReadOnOpen,
                  onChanged: prefs.setMarkAsReadOnOpen,
                ),
                SettingsRow(
                  icon: Icons.article_outlined,
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
                  icon: Icons.layers_outlined,
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
                  icon: Icons.delete_outline_rounded,
                  title: 'Ask before deleting',
                  subtitle: 'A permanent delete always asks, whatever this is '
                      'set to.',
                  value: prefs.confirmDelete,
                  onChanged: prefs.setConfirmDelete,
                ),
                SettingsRow(
                  icon: Icons.draw_outlined,
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
                  icon: Icons.swipe_right_alt,
                  title: 'Swipe right',
                  subtitle: 'Across a message in the list',
                  value: prefs.swipeStart.label,
                  onTap: () => _chooseSwipe(context, prefs, start: true),
                ),
                SettingsRow(
                  icon: Icons.swipe_left_alt,
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
                  icon: Icons.brightness_6_outlined,
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
                SettingsRow(
                  icon: Icons.view_agenda_outlined,
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
                  icon: Icons.format_size_rounded,
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
                  icon: Icons.logout_rounded,
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
                  icon: Icons.help_outline_rounded,
                  title: 'How to sign in',
                  subtitle: 'Step-by-step, including app passwords',
                  onTap: () => Navigator.of(context).push(
                    aceRoute(const TutorialScreen()),
                  ),
                ),
                SettingsRow(
                  icon: Icons.info_outline_rounded,
                  title: 'About Ace Mail',
                  // Read from the installed package, so it cannot drift from
                  // what is actually on the device.
                  value: AppInfo.label,
                  onTap: () => _about(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

  void _about(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Ace Mail'),
        content: Text(
          'Version ${AppInfo.label}\n\n'
          'A native IMAP and SMTP client for mobile and desktop. '
          'Your credentials stay in this device\'s keychain and go only to '
          'your mail provider.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
