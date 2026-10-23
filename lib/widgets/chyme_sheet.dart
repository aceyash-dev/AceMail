import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../models/full_message.dart';
import '../models/message_summary.dart';
import '../screens/settings_screen.dart';
import '../services/chyme.dart';
import '../state/mail_controller.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/ace_snack.dart';
import '../util/dates.dart';
import '../util/routes.dart';
import 'ace_form_field.dart';
import 'ace_icon_view.dart';
import 'astryx_widgets.dart';

/// Chyme, as a sheet.
///
/// A sheet rather than a screen, for the same reason the composer is one: you
/// ask about the mail in front of you, and the mail stays in front of you.
///
/// What Chyme can see is assembled **here**, not fetched by the model. The app
/// already knows what is on screen; a model with a tool that can ask for more
/// mail is a model that can ask for all of it, and the difference matters more
/// than the convenience.
class ChymeSheet extends StatefulWidget {
  const ChymeSheet({super.key, this.seed});

  /// A prompt to open with, when the caller already knows what it wants —
  /// "write this reply" from the composer.
  final String? seed;

  static Future<void> show(BuildContext context, {String? seed}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => ChymeSheet(seed: seed),
    );
  }

  @override
  State<ChymeSheet> createState() => _ChymeSheetState();
}

class _ChymeSheetState extends State<ChymeSheet> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// The conversation, without the system turn — that is rebuilt per request,
  /// so a setting changed mid-conversation takes effect on the next question.
  final List<ChymeTurn> _turns = <ChymeTurn>[];

  bool _busy = false;
  String? _error;

  /// The search the last reply asked for, if it asked for one.
  String? _search;

  @override
  void initState() {
    super.initState();
    final String? seed = widget.seed;
    if (seed != null && seed.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(seed));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// What Chyme is told about the screen.
  ///
  /// A summary, and a deliberately short one: the sender, the subject and the
  /// date of the messages in view, and the body of the one that is open. Not the
  /// mailbox, not the attachments, not the other folders.
  String _context(
    MailController controller,
    Preferences prefs,
    FullMessage? open,
  ) {
    if (!prefs.chymeReadsMail) {
      return 'The person has turned off letting you read their mail. You can '
          'still help them write, and still answer questions about the app.';
    }

    final StringBuffer out = StringBuffer()
      ..writeln('Folder on screen: ${controller.selectedFolder?.label ?? 'mail'}.');

    final List<MessageSummary> visible = controller.visibleMessages;
    if (visible.isNotEmpty) {
      out.writeln('The messages in it, newest first:');
      for (final MessageSummary message in visible.take(25)) {
        out.writeln(
          '- ${message.fromName} <${message.fromEmail}> · ${message.subject}'
          ' · ${formatListDate(message.date)}'
          '${message.isSeen ? '' : ' · unread'}',
        );
      }
    }

    if (open != null) {
      final String body = open.textBody;
      out
        ..writeln()
        ..writeln('The message they have open:')
        ..writeln('From: ${open.fromName} <${open.fromEmail}>')
        ..writeln('Subject: ${open.subject}')
        ..writeln('Date: ${open.date}')
        ..writeln('--- body ---')
        ..writeln(body.length > 6000 ? body.substring(0, 6000) : body);
    }

    return out.toString();
  }

  Future<void> _send(String text) async {
    final String prompt = text.trim();
    if (prompt.isEmpty || _busy) return;

    final Preferences prefs = context.read<Preferences>();
    if (prefs.chymeEndpoint.trim().isEmpty || prefs.chymeModel.trim().isEmpty) {
      setState(() => _error = 'Chyme has no endpoint or model yet.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _search = null;
      _turns.add(ChymeTurn('user', prompt));
    });
    _input.clear();
    _scrollToEnd();

    try {
      final MailController controller = context.read<MailController>();
      final List<ChymeTurn> request = <ChymeTurn>[
        ChymeTurn(
          'system',
          '${Chyme.systemPrompt}\n${_context(controller, prefs, controller.openMessage)}',
        ),
        ..._turns,
      ];

      final String reply = await Chyme.ask(
        endpoint: prefs.chymeEndpoint,
        apiKey: prefs.chymeKey,
        model: prefs.chymeModel,
        turns: request,
      );
      if (!mounted) return;
      setState(() {
        _turns.add(ChymeTurn('assistant', reply));
        _search = Chyme.searchFrom(reply);
      });
      _scrollToEnd();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AstryxMotion.of(const Duration(milliseconds: 220)),
        curve: AstryxMotion.emphasized,
      );
    });
  }

  /// Runs the search the reply asked for — after the person taps it, not
  /// instead of them asking.
  void _applySearch(String query) {
    context.read<MailController>().search(query);
    Navigator.of(context).pop();
    AceSnack.show(context, 'Searching for “$query”');
  }

  Future<void> _openSettings() async {
    Navigator.of(context).pop();
    await Navigator.of(context).push(aceRoute(const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final Preferences prefs = context.watch<Preferences>();
    final bool configured =
        prefs.chymeEndpoint.trim().isNotEmpty && prefs.chymeModel.trim().isNotEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController sheetController) {
        return Column(
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
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c.accentMuted,
                      borderRadius: BorderRadius.circular(AstryxRadius.element),
                    ),
                    child: Center(
                      child: AceIconView(
                        icon: AceIcons.chyme,
                        size: 18,
                        color: c.onAccentMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: AstryxSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Chyme', style: AstryxText.heading3(c.textPrimary)),
                        Text(
                          prefs.chymeModel.isEmpty
                              ? 'Not set up yet'
                              : prefs.chymeModel,
                          overflow: TextOverflow.ellipsis,
                          style: AstryxText.supporting(c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  AceIconButton(
                    icon: AceIcons.settings,
                    tooltip: 'Chyme settings',
                    onPressed: _openSettings,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Expanded(
              child: !configured
                  ? _NotSetUp(onConfigure: _openSettings)
                  : ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(
                        AstryxSpace.s5,
                        AstryxSpace.s4,
                        AstryxSpace.s5,
                        AstryxSpace.s4,
                      ),
                      children: <Widget>[
                        if (_turns.isEmpty) _suggestions(c),
                        for (final ChymeTurn turn in _turns)
                          _Bubble(turn: turn),
                        if (_search != null)
                          _SearchOffer(
                            query: _search!,
                            onTap: () => _applySearch(_search!),
                          ),
                        if (_busy) _thinking(c),
                        if (_error != null) ...<Widget>[
                          const SizedBox(height: AstryxSpace.s3),
                          AceErrorBox(message: _error!),
                        ],
                      ],
                    ),
            ),
            if (configured)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AstryxSpace.s5,
                  0,
                  AstryxSpace.s4,
                  AstryxSpace.s4,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _input,
                        onSubmitted: _send,
                        textInputAction: TextInputAction.send,
                        style: AstryxText.body(c.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Ask about your mail, or ask it to write',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AstryxRadius.full),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AstryxSpace.s2),
                    AceIconButton(
                      icon: AceIcons.send,
                      tooltip: 'Send',
                      variant: AceIconButtonVariant.filled,
                      onPressed: _busy ? null : () => _send(_input.text),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// What to ask, when somebody has opened Chyme and does not know what to ask.
  Widget _suggestions(AstryxColors c) {
    const List<String> prompts = <String>[
      'What needs answering today?',
      'Summarise the message I have open.',
      'Draft a short reply to this.',
      'Find mail from my bank.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Chyme reads what is on screen and nothing else. It can summarise, '
          'draft and find — and it will tell you when it cannot see something.',
          style: AstryxText.supporting(c.textSecondary),
        ),
        const SizedBox(height: AstryxSpace.s4),
        for (final String prompt in prompts) ...<Widget>[
          AceChip(
            label: prompt,
            icon: AceIcons.chyme,
            onTap: () => _send(prompt),
          ),
          const SizedBox(height: AstryxSpace.s2),
        ],
      ],
    );
  }

  Widget _thinking(AstryxColors c) {
    return Padding(
      padding: const EdgeInsets.only(top: AstryxSpace.s3),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 6, height: 6, child: AceLoader(size: 6)),
          const SizedBox(width: AstryxSpace.s3),
          Text('Thinking…', style: AstryxText.supporting(c.textSecondary)),
        ],
      ),
    );
  }
}

/// One turn, as a bubble.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});

  final ChymeTurn turn;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final bool mine = turn.role == 'user';
    final String text =
        mine ? turn.content : Chyme.withoutSearchLine(turn.content);

    return Padding(
      padding: const EdgeInsets.only(bottom: AstryxSpace.s3),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: <Widget>[
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AstryxSpace.s4,
                vertical: AstryxSpace.s3,
              ),
              decoration: BoxDecoration(
                color: mine ? c.accent : c.backgroundMuted,
                borderRadius: BorderRadius.circular(AstryxRadius.container),
              ),
              child: SelectableText(
                text,
                style: AstryxText.body(mine ? c.onAccent : c.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The search a reply asked for, offered rather than run.
class _SearchOffer extends StatelessWidget {
  const _SearchOffer({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Padding(
      padding: const EdgeInsets.only(bottom: AstryxSpace.s3),
      child: Container(
        padding: const EdgeInsets.all(AstryxSpace.s3),
        decoration: BoxDecoration(
          color: c.backgroundMuted,
          borderRadius: BorderRadius.circular(AstryxRadius.container),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: <Widget>[
            AceIconView(icon: AceIcons.search, size: 18, color: c.textSecondary),
            const SizedBox(width: AstryxSpace.s3),
            Expanded(
              child: Text(
                'Search for “$query”',
                style: AstryxText.body(c.textPrimary),
              ),
            ),
            AceButton(
              label: 'Search',
              variant: AceButtonVariant.tonal,
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// Chyme with nowhere to ask.
class _NotSetUp extends StatelessWidget {
  const _NotSetUp({required this.onConfigure});

  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Padding(
      padding: const EdgeInsets.all(AstryxSpace.s5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Chyme needs somewhere to ask', style: AstryxText.heading3(c.textPrimary)),
          const SizedBox(height: AstryxSpace.s2),
          Text(
            'There is no Chyme service and no account to make. Point it at any '
            'endpoint that speaks the OpenAI chat API — a hosted one, or a model '
            'running on your own machine — and it will list what it has.',
            style: AstryxText.body(c.textSecondary),
          ),
          const SizedBox(height: AstryxSpace.s4),
          AceButton(
            label: 'Set up Chyme',
            icon: AceIcons.chyme,
            variant: AceButtonVariant.primary,
            expand: true,
            onPressed: onConfigure,
          ),
        ],
      ),
    );
  }
}
