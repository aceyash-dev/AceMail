import 'package:flutter/material.dart';

import '../data/app_info.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import 'ace_icon_view.dart';
import 'astryx_widgets.dart';

/// Which document the sheet is showing.
enum LegalDocument {
  terms('Terms'),
  privacy('Privacy');

  const LegalDocument(this.label);

  final String label;
}

/// One section of a document.
typedef LegalSection = ({String heading, List<String> body});

/// The terms and the privacy policy, in one sheet.
///
/// Written to be **read**: short sections, plain sentences, and a heading for
/// each, so somebody looking for one answer can find it. A policy nobody reads
/// protects nobody — and a mail client is a place where the questions are
/// concrete: where is my password kept, what leaves the phone, what happens to
/// the messages on disk.
///
/// Every statement here is a statement about what the code does, and the code is
/// the source of truth. If a claim here ever stops being true, it is a bug in
/// this file.
class LegalSheet extends StatefulWidget {
  const LegalSheet({super.key, this.startAt = LegalDocument.terms});

  final LegalDocument startAt;

  static Future<void> show(
    BuildContext context, {
    LegalDocument startAt = LegalDocument.terms,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => LegalSheet(startAt: startAt),
    );
  }

  @override
  State<LegalSheet> createState() => _LegalSheetState();
}

class _LegalSheetState extends State<LegalSheet> {
  late LegalDocument _document = widget.startAt;

  /// Where the app says things out loud.
  ///
  /// The same address the About sheet shows, because a policy with no way to
  /// ask a question about it is a policy you cannot hold anyone to.
  static const String contact = 'hello@ace-base.cc';

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final List<LegalSection> sections = _document == LegalDocument.terms
        ? _terms
        : _privacy;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (BuildContext context, ScrollController scrollController) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AstryxSpace.s5,
                0,
                AstryxSpace.s5,
                AstryxSpace.s3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _document == LegalDocument.terms
                        ? 'Terms of use'
                        : 'Privacy policy',
                    style: AstryxText.heading2(c.textPrimary),
                  ),
                  const SizedBox(height: AstryxSpace.s3),
                  // A segmented switch rather than two sheets: they are the two
                  // halves of the same question, and the answer to one is often
                  // one line into the other.
                  Row(
                    children: <Widget>[
                      for (final LegalDocument document
                          in LegalDocument.values) ...<Widget>[
                        Expanded(
                          child: _Tab(
                            label: document.label,
                            active: document == _document,
                            onTap: () => setState(() => _document = document),
                          ),
                        ),
                        if (document != LegalDocument.values.last)
                          const SizedBox(width: AstryxSpace.s2),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AstryxSpace.s5,
                  AstryxSpace.s4,
                  AstryxSpace.s5,
                  AstryxSpace.s8,
                ),
                children: <Widget>[
                  for (final LegalSection section in sections) ...<Widget>[
                    Text(section.heading, style: AstryxText.heading3(c.textPrimary)),
                    const SizedBox(height: AstryxSpace.s2),
                    for (final String paragraph in section.body) ...<Widget>[
                      Text(paragraph, style: AstryxText.body(c.textSecondary)),
                      const SizedBox(height: AstryxSpace.s3),
                    ],
                    const SizedBox(height: AstryxSpace.s2),
                  ],
                  const SizedBox(height: AstryxSpace.s2),
                  Row(
                    children: <Widget>[
                      AceIconView(
                        icon: AceIcons.info,
                        size: 16,
                        color: c.textSecondary,
                      ),
                      const SizedBox(width: AstryxSpace.s2),
                      Expanded(
                        child: Text(
                          'Questions, or something here that is not true of the '
                          'app you are running: $contact',
                          style: AstryxText.supporting(c.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AstryxSpace.s3),
                  Text(
                    'Version ${AppInfo.version} · last reviewed October 2026. '
                    'This is a plain-language summary of what the app does, not '
                    'legal advice.',
                    style: AstryxText.supporting(c.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return AceSpringy(
      onTap: onTap,
      semanticLabel: label,
      builder: (BuildContext context, double press, bool hover) => AnimatedContainer(
        duration: AstryxMotion.fast,
        padding: const EdgeInsets.symmetric(vertical: AstryxSpace.s2),
        decoration: BoxDecoration(
          color: active ? c.accent : c.backgroundMuted,
          borderRadius: BorderRadius.circular(AstryxRadius.full),
        ),
        child: Center(
          child: Text(
            label,
            style: AstryxText.label(active ? c.onAccent : c.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// What the terms say.
///
/// Short on purpose. A mail client is a tool, and the interesting clauses are
/// the ones about what it does with your mail — which is the other tab.
const List<LegalSection> _terms = <LegalSection>[
  (
    heading: 'What this is',
    body: <String>[
      'Ace Mail is an email client. It connects to mail servers you already '
          'have an account on — it is not a mail service, it does not run a '
          'server, and it never sees your mail.',
      'It is provided as it is. There is no warranty that it will be free of '
          'faults, and no promise that any particular server will work with it.',
    ],
  ),
  (
    heading: 'Your account, your responsibility',
    body: <String>[
      'You sign in with an app password, which you generate at your mail '
          'provider. Keep it as safe as your password: anyone with it can read '
          'your mail, whether or not they have this app.',
      'Removing an account from the app deletes the password from this device. '
          'It does not close your account, and it does not change anything on '
          'the server — revoke the app password at your provider for that.',
    ],
  ),
  (
    heading: 'Using it fairly',
    body: <String>[
      'Do not use Ace Mail to break the terms of your mail provider, to send '
          'mail nobody asked for, or to do anything unlawful. The app will not '
          'stop you; your provider will.',
    ],
  ),
  (
    heading: 'Sending and delivery',
    body: <String>[
      'Sending hands a message to your provider’s outgoing server. Whether it '
          'is delivered, and when, is between that server and the recipient’s — '
          'the app can tell you what the server said, and nothing more.',
      'An error does not always mean nothing was sent. A connection that drops '
          'after the message is handed over is reported as unknown, and the app '
          'will not quietly try again, because that is how a message is sent '
          'twice.',
    ],
  ),
  (
    heading: 'Changes',
    body: <String>[
      'These terms may change with a release. The changelog says what changed, '
          'and the version this copy belongs to is at the foot of this sheet.',
    ],
  ),
];

/// What the privacy policy says.
///
/// Every line is a description of the code. Where the app sends something off
/// the device, it is named, and it is a setting.
const List<LegalSection> _privacy = <LegalSection>[
  (
    heading: 'The short version',
    body: <String>[
      'There is no Ace Mail server. Your mail goes between this device and your '
          'own mail provider, and nowhere else. There is no analytics, no '
          'telemetry, no crash reporting and no advertising.',
    ],
  ),
  (
    heading: 'What is kept on this device',
    body: <String>[
      'Your account addresses and app passwords, in the device keychain — the '
          'same place your operating system keeps other passwords, protected by '
          'the device’s own lock.',
      'Your settings, in the same keychain.',
      'The draft you are writing and the messages you have read, in an '
          'encrypted cache: AES-256-GCM, with the key in the keychain and a '
          'fresh nonce per record. “Clear cached content” in Settings removes '
          'them, and the keys with them.',
      'Nothing is kept if you turn “Keep messages on this device” off.',
    ],
  ),
  (
    heading: 'What leaves this device',
    body: <String>[
      'Your mail, to your mail provider, over TLS, with the certificate '
          'validated. That is the connection you signed in for.',
      'A hash of a sender’s address, to gravatar.com, when “Sender pictures” is '
          'on. A hash of an address is not anonymous — addresses are guessable '
          'and can be hashed by anyone — so this is a disclosure, and turning it '
          'off means no request is ever made.',
      'Images in a message, fetched from the sender’s server, when “Load images '
          'in messages” is on. Fetching one tells that server the message was '
          'opened, and from where. Off, a placeholder is shown in its place.',
      'A brand mark, from a domain’s own server, when a sender publishes one '
          '(BIMI). It is a logo lookup, not a tracking pixel.',
      'The address of a link, to the app that opens it, when you tap it. The '
          'app asks first unless you have turned that off.',
      'Nothing else. No usage data, no device identifiers, no address book, no '
          'location.',
    ],
  ),
  (
    heading: 'Notifications',
    body: <String>[
      'New-mail notifications are drawn by your device. By default they say that '
          'mail has arrived and not who sent it or what it says, and they are '
          'marked private, so a device set to hide sensitive content hides them.',
    ],
  ),
  (
    heading: 'The lock',
    body: <String>[
      '“Require unlock” asks your device for a fingerprint, a face or its '
          'passcode before the app opens. The app never sees that — your device '
          'answers yes or no, and that is all it gets.',
    ],
  ),
  (
    heading: 'Removing things',
    body: <String>[
      'Removing an account deletes its password and its cached messages from '
          'this device. “Clear cached content” deletes every draft and cached '
          'message. Uninstalling the app removes all of it, because none of it '
          'lives anywhere else.',
    ],
  ),
];
