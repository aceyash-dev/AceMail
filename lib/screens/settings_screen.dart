import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/routes.dart';
import '../widgets/account_sheet.dart';
import '../widgets/settings_group.dart';
import 'tutorial_screen.dart';

/// The app's settings. Every row here changes something real.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Mirrors `version:` in pubspec.yaml. Shown in About.
  static const String version = '0.3.1';

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
                  value: version,
                  onTap: () => _about(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
        content: const Text(
          'Version $version\n\n'
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
