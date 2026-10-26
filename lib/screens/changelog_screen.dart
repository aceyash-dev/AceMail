import 'package:flutter/material.dart';

import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../widgets/markdown_view.dart';
import '../widgets/whats_new.dart';

/// The changelog, in full.
///
/// The sheet after an update shows one version, because that is what changed
/// since you last looked. This is the file — every version, newest first — for
/// when somebody wants to know what a release they skipped actually did, or why
/// a setting they never touched moved.
class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key});

  static Future<void> show(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const ChangelogScreen(),
        ),
      );

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  late final Future<String?> _notes = ReleaseNotes.all();

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    return Scaffold(
      backgroundColor: c.backgroundBody,
      appBar: AppBar(title: const Text('Changelog')),
      body: FutureBuilder<String?>(
        future: _notes,
        builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final String? body = snapshot.data;
          if (body == null || body.trim().isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AstryxSpace.s6),
                child: Text(
                  'The changelog could not be read from this build.',
                  textAlign: TextAlign.center,
                  style: AstryxText.body(c.textSecondary),
                ),
              ),
            );
          }
          return Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AstryxSpace.s5,
                AstryxSpace.s4,
                AstryxSpace.s5,
                AstryxSpace.s7,
              ),
              child: MarkdownView(source: body),
            ),
          );
        },
      ),
    );
  }
}
