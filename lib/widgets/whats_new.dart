import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../data/app_info.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../theme/astryx_tokens.dart';
import '../theme/astryx_theme.dart';
import 'astryx_widgets.dart';

/// The release notes for the version that is running.
///
/// Read from the changelog the repo already keeps, bundled as an asset, rather
/// than a second list that would drift from it. An update that changes things
/// should say what it changed — otherwise the only way to find out is to notice.
abstract final class ReleaseNotes {
  static String? _cache;

  /// The section of the changelog for [version], or null when there is none.
  static Future<String?> forVersion(String version) async {
    final String changelog;
    try {
      changelog = _cache ??= await rootBundle.loadString('assets/CHANGELOG.md');
    } catch (_) {
      return null;
    }

    // Headings look like `## 0.5.0+27`. Find that one and take everything up to
    // the next heading of the same level.
    final RegExp heading = RegExp(r'^## +' + RegExp.escape(version) + r'\b.*$',
        multiLine: true);
    final RegExpMatch? match = heading.firstMatch(changelog);
    if (match == null) return null;

    final String rest = changelog.substring(match.end);
    final int next = rest.indexOf('\n## ');
    final String body = (next == -1 ? rest : rest.substring(0, next)).trim();
    return body.isEmpty ? null : body;
  }
}

/// Shows what changed, once, the first time a version runs.
class WhatsNewSheet extends StatelessWidget {
  const WhatsNewSheet({super.key, required this.notes});

  final String notes;

  static Future<void> showIfUpdated(BuildContext context) async {
    final String? seen = context.read<Preferences>().lastSeenVersion;
    final String running = AppInfo.version;

    // First run after install: nothing to compare against, and a wall of
    // release notes is a poor introduction to an app.
    if (seen == null || seen == running) return;

    final String? body = await ReleaseNotes.forVersion(running);
    if (body == null || !context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) =>
          WhatsNewSheet(notes: body),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AstryxSpace.s5,
            0,
            AstryxSpace.s5,
            AstryxSpace.s5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const BrandMark(size: 28),
                  const SizedBox(width: AstryxSpace.s3),
                  Expanded(
                    child: Text(
                      "What's new in ${AppInfo.version}",
                      style: AstryxText.heading3(c.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AstryxSpace.s4),
              Text(notes, style: AstryxText.body(c.textPrimary)),
              const SizedBox(height: AstryxSpace.s5),
              SizedBox(
                width: double.infinity,
                child: AceButton(
                  label: 'Got it',
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
