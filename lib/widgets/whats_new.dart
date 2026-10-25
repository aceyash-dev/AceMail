import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../data/app_info.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../theme/astryx_tokens.dart';
import '../theme/astryx_theme.dart';
import 'astryx_widgets.dart';
import 'markdown_view.dart';

/// The release notes for the version that is running.
///
/// Read from the changelog the repo already keeps, bundled as an asset, rather
/// than a second list that would drift from it. An update that changes things
/// should say what it changed — otherwise the only way to find out is to notice.
abstract final class ReleaseNotes {
  static String? _cache;

  /// The section of the changelog for [version], or null when there is none.
  ///
  /// [version] is the full `name+build`, which is what the headings carry. A
  /// heading without a build number still matches, so a changelog written by
  /// hand does not have to know about them.
  static Future<String?> forVersion(String version) async {
    final String changelog;
    try {
      changelog = _cache ??= await rootBundle.loadString('assets/CHANGELOG.md');
    } catch (_) {
      return null;
    }

    return sectionFor(changelog, version) ??
        sectionFor(changelog, version.split('+').first);
  }

  /// The body of the `## <version>` section of [changelog], or null.
  ///
  /// Pure, so the heading rule can be tested against a literal changelog rather
  /// than against whatever the app happens to be bundled with.
  static String? sectionFor(String changelog, String version) {
    if (version.isEmpty) return null;

    // Headings look like `## 0.5.1+34`. The version has to be the *whole* of
    // what follows `##` — a trailing title is allowed, a `+34` on the end is
    // not, or asking for `0.5.1` would answer with `0.5.1+34`'s section.
    final RegExp heading = RegExp(
      r'^## +' + RegExp.escape(version) + r'(\s.*)?$',
      multiLine: true,
    );
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
    // The whole version, build number included. Comparing names alone meant
    // that 0.5.1+33 to 0.5.1+34 — which is how this app ships a change — said
    // nothing at all.
    final String running = AppInfo.fullVersion;

    if (running.isEmpty || seen == running) return;

    // First run after install: nothing to compare against, and a wall of
    // release notes is a poor introduction to an app. The version is still
    // *recorded*, though — it was not, and that was the bug: a fresh install
    // returned here without writing anything, so the next update found no
    // "seen" to compare against and said nothing either. The notes only ever
    // appeared to somebody who had already seen them once.
    if (seen == null) {
      await context.read<Preferences>().setLastSeenVersion(running);
      return;
    }

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
              // Rendered, not printed. The changelog is markdown and this
              // handed it to a Text, so `### Added` and `**bold**` arrived on
              // screen exactly as written — the release notes read like a diff.
              MarkdownView(source: notes),
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
