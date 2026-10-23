import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_info.dart';
import '../data/preferences.dart';
import '../models/glass_mode.dart';
import '../models/mail_folder.dart';
import '../state/mail_controller.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/ace_snack.dart';
import 'astryx_widgets.dart';
import 'settings_group.dart';

/// What the app is doing, for when it is not doing it.
///
/// Deliberately **no message content, no subjects, no senders and no search
/// text**. Everything here is about the machinery — what is connected, what is
/// loaded, what is cached, which version is running — because that is what
/// answers "why is it doing that", and a diagnostics panel that leaks the
/// mailbox is a liability rather than a tool. The one exception is the account's
/// own address, which is on the screen the person is already looking at.
///
/// Written after an audit asked for observability without private data. The
/// distinction it draws is the useful one: counts and states are safe, contents
/// are not.
abstract final class DiagnosticsSheet {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.94,
        builder: (BuildContext context, ScrollController scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(
            AstryxSpace.s5,
            0,
            AstryxSpace.s5,
            AstryxSpace.s6,
          ),
          children: <Widget>[
            Text('Diagnostics', style: AstryxText.heading1(sheetContext.astryx.textPrimary)),
            const SizedBox(height: AstryxSpace.s1),
            Text(
              'What the app is doing, and what it is keeping',
              style: AstryxText.body(sheetContext.astryx.textSecondary),
            ),
            const SizedBox(height: AstryxSpace.s5),
            const _Diagnostics(),
          ],
        ),
      ),
    );
  }
}

class _Diagnostics extends StatelessWidget {
  const _Diagnostics();

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final MailController controller = context.watch<MailController>();
    final Preferences prefs = context.watch<Preferences>();
    final MailFolder? folder = controller.selectedFolder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SettingsGroup(
          title: 'Connection',
          children: <Widget>[
            _Line(
              label: 'Account',
              // The person's own address, on a screen they opened themselves.
              value: controller.account?.email ?? 'None',
            ),
            _Line(
              label: 'State',
              value: controller.connecting
                  ? 'Connecting'
                  : controller.isReady
                      ? 'Connected'
                      : 'Not connected',
            ),
            if (controller.sessionError != null)
              _Line(
                label: 'Last error',
                value: controller.sessionError!,
                // An error is the one thing here that is worth reading twice.
                emphasis: true,
              ),
          ],
        ),
        const SizedBox(height: AstryxSpace.s5),
        SettingsGroup(
          title: 'Loaded',
          children: <Widget>[
            _Line(
              label: 'Folder',
              value: folder == null
                  ? 'None'
                  : '${folder.label} (${folder.role.name})',
            ),
            _Line(label: 'Messages', value: '${controller.messages.length}'),
            _Line(
              label: 'More on the server',
              value: controller.hasMore ? 'Yes' : 'No',
            ),
            _Line(
              label: 'Search',
              // Whether, not what. The words somebody searched for are theirs,
              // and this panel does not need them to be useful.
              value: controller.searchQuery == null
                  ? 'No search'
                  : 'A search is active',
            ),
          ],
        ),
        const SizedBox(height: AstryxSpace.s5),
        SettingsGroup(
          title: 'Local cache',
          children: <Widget>[
            _Line(label: 'Records', value: '${controller.cacheEntries}'),
            _Line(label: 'Size', value: _bytes(controller.cacheBytes)),
            _Line(
              label: 'Sealed',
              value: 'AES-256-GCM, in the keychain',
            ),
          ],
        ),
        const SizedBox(height: AstryxSpace.s4),
        AceButton(
          label: 'Clear the cache',
          variant: AceButtonVariant.tonal,
          icon: AceIcons.deleteSweep,
          expand: true,
          onPressed: () async {
            await controller.clearCache();
            if (!context.mounted) return;
            AceSnack.show(context, 'The local cache is empty.');
          },
        ),
        const SizedBox(height: AstryxSpace.s1),
        Text(
          'Cached bodies and drafts are all still on the server. Clearing them '
          'costs nothing but the next download.',
          style: AstryxText.supporting(c.textSecondary),
        ),
        const SizedBox(height: AstryxSpace.s5),
        SettingsGroup(
          title: 'This build',
          children: <Widget>[
            _Line(label: 'Version', value: AppInfo.fullVersion),
            _Line(
              label: 'Features on',
              value: <String>[
                if (prefs.chymeEnabled) 'Chyme',
                if (prefs.appLock) 'App lock',
                if (prefs.privatePreviews) 'Private previews',
                if (prefs.glass != GlassMode.never) 'See-through surfaces',
              ].join(', '),
            ),
          ],
        ),
      ],
    );
  }

  static String _bytes(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AstryxSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Text(label, style: AstryxText.body(c.textSecondary)),
          ),
          const SizedBox(width: AstryxSpace.s3),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: emphasis
                  ? AstryxText.bodyStrong(c.warning)
                  : AstryxText.bodyStrong(c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
