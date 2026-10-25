import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_info.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import 'astryx_widgets.dart';
import 'ace_icon_view.dart';

/// What Ace Mail is, who makes it, and what it does with your credentials.
///
/// A sheet rather than a dialog: it is read, not answered, and a sheet can be
/// scrolled and dismissed with the same gesture as everything else in the app.
/// Shared by Settings and the sidebar, so the two cannot drift into telling
/// different stories about the same app.
Future<void> showAceAbout(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => _AboutSheet(sheetContext: sheetContext),
  );
}

class _AboutSheet extends StatelessWidget {
  const _AboutSheet({required this.sheetContext});

  final BuildContext sheetContext;

  /// Where to find the people who made this.
  /// The source. It is the first thing in the list because it is the thing
  /// someone who wants to check a claim will look for.
  static final Uri _source = Uri.parse('https://github.com/tab-gl/AceMail');
  static final Uri _bluesky = Uri.parse('https://bsky.app/profile/ace-base.cc');
  static final Uri _email = Uri.parse('mailto:hello@ace-base.cc');
  static final Uri _website = Uri.parse('https://ace-base.cc');

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AstryxSpace.s5,
          0,
          AstryxSpace.s5,
          AstryxSpace.s6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                const BrandMark(size: 46),
                const SizedBox(width: AstryxSpace.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Ace Mail',
                        style: AstryxText.heading2(c.textPrimary),
                      ),
                      const SizedBox(height: AstryxSpace.s0_5),
                      Text(
                        AppInfo.label.isEmpty
                            ? 'Version unavailable'
                            : AppInfo.label,
                        style: AstryxText.label(c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AstryxSpace.s5),
            Text(
              'A native IMAP and SMTP client for mobile and desktop. Any '
              'provider, no vendor lock-in.',
              style: AstryxText.body(c.textPrimary),
            ),
            const SizedBox(height: AstryxSpace.s3),
            Text(
              'Your credentials stay in this device\'s keychain and go only to '
              'your mail provider. Sender pictures and remote images are off by '
              'default, because looking them up tells a third party what is in '
              'your mail.',
              style: AstryxText.supporting(c.textSecondary),
            ),
            const SizedBox(height: AstryxSpace.s6),
            Text('Find us', style: AstryxText.label(c.textSecondary)),
            const SizedBox(height: AstryxSpace.s2),
            _Handle(
              icon: AceIcons.github,
              platform: 'Source',
              handle: 'tab-gl/AceMail',
              onTap: () => _open(sheetContext, _source),
            ),
            _Handle(
              icon: AceIcons.globe,
              platform: 'Bluesky',
              handle: '@ace-base.cc',
              onTap: () => _open(sheetContext, _bluesky),
            ),
            _Handle(
              icon: AceIcons.mail,
              platform: 'Email',
              handle: 'hello@ace-base.cc',
              onTap: () => _open(sheetContext, _email),
            ),
            _Handle(
              icon: AceIcons.globe,
              platform: 'Website',
              handle: 'ace-base.cc',
              onTap: () => _open(sheetContext, _website),
            ),
            const SizedBox(height: AstryxSpace.s6),
            SizedBox(
              width: double.infinity,
              child: AceButton(
                label: 'Close',
                variant: AceButtonVariant.tonal,
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No browser, or the platform refused. Nothing to say about it.
    }
  }
}

class _Handle extends StatelessWidget {
  const _Handle({
    required this.icon,
    required this.platform,
    required this.handle,
    required this.onTap,
  });

  final AceIcon icon;
  final String platform;
  final String handle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return AceSpringy(
      onTap: onTap,
      semanticLabel: '$platform, $handle',
      builder: (BuildContext context, double press, bool hover) {
        final double t = press.clamp(0.0, 1.0);
        return Container(
          margin: const EdgeInsets.only(bottom: AstryxSpace.s2),
          padding: const EdgeInsets.symmetric(
            horizontal: AstryxSpace.s4,
            vertical: AstryxSpace.s3,
          ),
          decoration: BoxDecoration(
            color: hover ? c.surfaceHighest : c.backgroundMuted,
            borderRadius: BorderRadius.circular(
              lerpDouble(AstryxRadius.container, AstryxRadius.element, t)!,
            ),
          ),
          child: Row(
            children: <Widget>[
              AceIconView(icon: icon, size: 19, color: c.textAccent),
              const SizedBox(width: AstryxSpace.s3),
              Expanded(
                child: Text(platform, style: AstryxText.body(c.textPrimary)),
              ),
              Text(
                handle,
                style: AstryxText.bodyStrong(c.textAccent),
              ),
              const SizedBox(width: AstryxSpace.s2),
              AceIconView(icon: AceIcons.openInNew, size: 15, color: c.iconSecondary),
            ],
          ),
        );
      },
    );
  }
}
