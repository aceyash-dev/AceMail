import 'package:flutter/material.dart';

import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../widgets/astryx_widgets.dart';

/// A step-by-step guide to signing in, reachable from the sign-in screen.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialStep {
  const _TutorialStep({
    required this.title,
    required this.lead,
    this.points = const <String>[],
  });

  final String title;
  final String lead;
  final List<String> points;
}

const List<_TutorialStep> _steps = <_TutorialStep>[
  _TutorialStep(
    title: 'What you need',
    lead: 'Ace Mail talks to your mail provider directly over IMAP and SMTP. '
        'Nothing passes through a server of ours.',
    points: <String>[
      'Your full email address, for example you@gmail.com',
      'An app password, not your normal account password — step 3 explains it',
      'A working internet connection on this device',
    ],
  ),
  _TutorialStep(
    title: 'We find your servers',
    lead: 'Type your address and the IMAP and SMTP servers are filled in for '
        'you. Gmail, Outlook, Hotmail, Yahoo, iCloud, Zoho, Rediffmail, '
        'Fastmail and Proton Bridge are all recognised.',
    points: <String>[
      'Tap the Email address field and type your address',
      'Open Advanced server settings if you want to check what was filled in',
      'Using something else? That is step 5',
    ],
  ),
  _TutorialStep(
    title: 'Create an app password',
    lead: 'Most providers refuse normal passwords from third-party apps. You '
        'need a one-off app password instead.',
    points: <String>[
      'Gmail — turn on 2-Step Verification, create one at '
          'myaccount.google.com/apppasswords, and switch IMAP on in '
          'Gmail › Settings › Forwarding and POP/IMAP',
      'Yahoo — Account Security › Generate app password',
      'iCloud — Apple ID › Sign-In and Security › App-Specific Passwords',
      'Outlook / Hotmail — Security › Advanced security options › '
          'App passwords',
    ],
  ),
  _TutorialStep(
    title: 'Sign in',
    lead: 'Enter your address and the app password, then tap Connect. The '
        'first connection can take a few seconds.',
    points: <String>[
      'Tap the eye icon to check what you typed',
      'Your password is kept in this device\'s keychain, never in a plain file',
      'You stay signed in until you sign out',
    ],
  ),
  _TutorialStep(
    title: 'Any other provider',
    lead: 'If your provider is not recognised, open Advanced server settings '
        'and enter the servers yourself.',
    points: <String>[
      'IMAP host — usually imap.yourprovider.com, port 993, SSL',
      'SMTP host — usually smtp.yourprovider.com, port 587, STARTTLS '
          '(or 465 for implicit TLS)',
      'Your provider\'s help pages will list both',
    ],
  ),
  _TutorialStep(
    title: 'If it does not connect',
    lead: 'The message under the form says what went wrong. These are the '
        'three common ones.',
    points: <String>[
      '"Could not reach …" — check the server address is spelled correctly, '
          'and that this device has internet',
      '"Sign-in was rejected" — you used your normal password; go back to '
          'step 3',
      'Still failing — your provider may need IMAP switched on in its own '
          'settings',
    ],
  ),
];

class _TutorialScreenState extends State<TutorialScreen> {
  int _index = 0;

  void _advance() {
    if (_index < _steps.length - 1) {
      setState(() => _index += 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _back() {
    if (_index > 0) setState(() => _index -= 1);
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final _TutorialStep step = _steps[_index];
    final bool isLast = _index == _steps.length - 1;

    return Scaffold(
      backgroundColor: c.backgroundBody,
      appBar: AppBar(title: const Text('How to sign in')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AstryxSpace.s5,
                    AstryxSpace.s4,
                    AstryxSpace.s5,
                    AstryxSpace.s2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'Step ${_index + 1} of ${_steps.length}',
                            style: AstryxText.label(c.textAccent),
                          ),
                          const Spacer(),
                          Text(
                            '${((_index + 1) * 100 ~/ _steps.length)}%',
                            style: AstryxText.supporting(c.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: AstryxSpace.s2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AstryxRadius.full),
                        child: LinearProgressIndicator(
                          value: (_index + 1) / _steps.length,
                          minHeight: 6,
                          backgroundColor: c.backgroundMuted,
                          valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AstryxSpace.s5,
                      AstryxSpace.s3,
                      AstryxSpace.s5,
                      AstryxSpace.s5,
                    ),
                    child: AceSurface(
                      padding: const EdgeInsets.all(AstryxSpace.s5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(step.title, style: AstryxText.heading1(c.textPrimary)),
                          const SizedBox(height: AstryxSpace.s3),
                          Text(step.lead, style: AstryxText.body(c.textSecondary)),
                          if (step.points.isNotEmpty) ...<Widget>[
                            const SizedBox(height: AstryxSpace.s5),
                            for (final String point in step.points)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AstryxSpace.s3,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.only(
                                        top: 7,
                                        right: AstryxSpace.s3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: c.accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        point,
                                        style: AstryxText.body(c.textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
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
                      if (_index > 0)
                        AceButton(
                          label: 'Back',
                          icon: Icons.arrow_back_rounded,
                          onPressed: _back,
                        )
                      else
                        AceButton(
                          label: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      const Spacer(),
                      AceButton(
                        label: isLast ? 'Got it' : 'Next',
                        variant: AceButtonVariant.primary,
                        icon: isLast ? Icons.check_rounded : null,
                        onPressed: _advance,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
