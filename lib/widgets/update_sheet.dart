import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_info.dart';
import '../data/preferences.dart';
import '../services/update_check.dart';
import '../services/update_installer.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/ace_snack.dart';
import '../util/dates.dart';
import 'ace_glass.dart';
import 'astryx_widgets.dart';
import 'markdown_view.dart';

/// A newer release, when there is one.
///
/// Shown once per launch at most, and only when the check found something
/// newer than what is installed. It carries the release notes, because "there
/// is an update" without saying what changed is a notification that asks for
/// trust rather than earning it.
class UpdateSheet extends StatefulWidget {
  const UpdateSheet({super.key, required this.release});

  final UpdateRelease release;

  static Future<void> show(BuildContext context, UpdateRelease release) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      sheetAnimationStyle: kAceSheetMotion,
      builder: (BuildContext sheetContext) => UpdateSheet(release: release),
    );
  }

  @override
  State<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<UpdateSheet> {
  /// 0 to 1 while downloading, null when nothing is in flight.
  double? _progress;
  String? _note;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scroll) => Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AstryxSpace.s5,
              0,
              AstryxSpace.s5,
              AstryxSpace.s3,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Ace Mail ${widget.release.version}',
                        style: AstryxText.heading3(c.textPrimary),
                      ),
                      Text(
                        // The label the About screen uses: name and build, in
                        // a shape that cannot come out as "0.6.0+1091".
                        AppInfo.label.isEmpty
                            ? 'You are on an older build'
                            : 'You are on ${AppInfo.label}',
                        style: AstryxText.supporting(c.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (widget.release.published != null)
                  Text(
                    formatListDate(widget.release.published),
                    style: AstryxText.supporting(c.textSecondary),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(
                AstryxSpace.s5,
                AstryxSpace.s4,
                AstryxSpace.s5,
                AstryxSpace.s4,
              ),
              children: <Widget>[
                if (widget.release.hasNotes)
                  MarkdownView(
                    // Stripped first: an older release body was written as an
                    // HTML accordion, and this view has no HTML in it.
                    source: UpdateCheck.plainNotes(widget.release.notes),
                    onLink: (String url) => _open(context, url),
                  )
                else
                  Text(
                    'This release did not come with notes.',
                    style: AstryxText.body(c.textSecondary),
                  ),
              ],
            ),
          ),
          if (_progress != null || _note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AstryxSpace.s5,
                0,
                AstryxSpace.s5,
                AstryxSpace.s3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_progress != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AstryxRadius.full),
                      child: LinearProgressIndicator(value: _progress),
                    ),
                  if (_note != null)
                    Text(_note!, style: AstryxText.supporting(c.textSecondary)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AstryxSpace.s5,
              0,
              AstryxSpace.s5,
              AstryxSpace.s5,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: AceButton(
                    // On Android the app can fetch the release and hand it to
                    // the installer; everywhere else the release page is the
                    // only honest destination.
                    label: widget.release.apkUrl != null &&
                            UpdateInstaller.canInstall
                        ? 'Update now'
                        : 'Release page',
                    icon: widget.release.apkUrl != null &&
                            UpdateInstaller.canInstall
                        ? AceIcons.save
                        : AceIcons.openInNew,
                    variant: AceButtonVariant.primary,
                    expand: true,
                    loading: _progress != null,
                    onPressed: _progress != null
                        ? null
                        : () => widget.release.apkUrl != null &&
                                UpdateInstaller.canInstall
                            ? _install(context)
                            : _open(context, widget.widget.release.url),
                  ),
                ),
                const SizedBox(width: AstryxSpace.s2),
                AceButton(
                  label: 'Later',
                  variant: AceButtonVariant.ghost,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Fetches the release and hands it to the installer.
  ///
  /// Two steps, and both are visible: a progress bar while the file comes down,
  /// then the system's own installer — which, the first time, is a screen
  /// asking whether this app may install apps. That screen is the permission,
  /// and there is no version of this that skips it.
  Future<void> _install(BuildContext context) async {
    setState(() {
      _progress = 0;
      _note = null;
    });

    final File? file = await UpdateInstaller.download(
      widget.release,
      onProgress: (double value) {
        if (mounted) setState(() => _progress = value);
      },
    );

    if (!mounted) return;
    if (file == null) {
      setState(() {
        _progress = null;
        _note = 'The download did not finish. Try again, or open the release '
            'page.';
      });
      return;
    }

    final bool started = await UpdateInstaller.install(file);
    if (!mounted) return;
    setState(() {
      _progress = null;
      _note = started
          ? 'The installer is open. Ace Mail is replaced, not added to.'
          : 'Android would not start the installer. Allow Ace Mail to install '
              'apps in the system settings, then try again.';
    });
  }

  Future<void> _open(BuildContext context, String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return;
    final bool opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      AceSnack.show(context, 'Could not open $url');
    }
  }
}

/// Asks GitHub, and says something only when there is something to say.
///
/// Called after the first frame, so a launch never waits on the network: the
/// mailbox draws, and the answer arrives when it arrives. The check itself is
/// throttled to once a day by [Preferences.shouldCheckForUpdates], which is
/// what keeps a public API's rate limit from being somebody's problem.
Future<void> announceUpdateIfAny(BuildContext context) async {
  final Preferences prefs = context.read<Preferences>();
  if (!prefs.shouldCheckForUpdates) return;

  final UpdateRelease? release = await UpdateCheck.latest();
  // Only a real answer counts. Recording the time on a failed request meant one
  // launch without a network — or one rate-limited request — silenced the check
  // for a whole day, which is the shape of "the update checker does not work":
  // it never asks again, and never says why.
  if (release == null) return;
  await prefs.setLastUpdateCheck(DateTime.now());
  if (!context.mounted) return;
  if (!UpdateCheck.isNewer(release.version, AppInfo.fullVersion)) return;

  // Fetched now rather than when somebody taps Update: the download is the slow
  // part, and it is the part nobody is watching. Installing stays a tap.
  if (prefs.autoUpdate && UpdateInstaller.canInstall) {
    unawaited(UpdateInstaller.download(release));
  }

  await UpdateSheet.show(context, release);
}

/// Asks now, at somebody's request, and always answers.
///
/// The launch check is silent about failure because nobody asked; this one was
/// asked, so "you are up to date", "there is a newer build" and "I could not
/// check" are three different things to say and it says which.
Future<void> checkForUpdatesNow(BuildContext context) async {
  final UpdateRelease? release = await UpdateCheck.latest();
  if (!context.mounted) return;

  if (release == null) {
    AceSnack.show(context, 'Could not reach the release list. Try again later.');
    return;
  }
  if (!UpdateCheck.isNewer(release.version, AppInfo.fullVersion)) {
    AceSnack.show(
      context,
      AppInfo.fullVersion.isEmpty
          ? 'You are on the newest release: ${widget.release.version}.'
          : 'You are on the newest release (${AppInfo.fullVersion}).',
    );
    return;
  }
  await UpdateSheet.show(context, release);
}
