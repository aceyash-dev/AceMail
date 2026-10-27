import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../models/contact.dart';
import '../models/full_message.dart';
import '../models/message_summary.dart';
import '../screens/compose_screen.dart';
import '../screens/settings_screen.dart';
import '../services/chyme.dart';
import '../services/contacts.dart';
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
import 'chyme_mark.dart';
import 'chyme_pickers.dart';
import 'markdown_view.dart';

/// Chyme, as a sheet.
///
/// A sheet rather than a screen, for the same reason the composer is one: you
/// ask about the mail in front of you, and the mail stays in front of you.
///
/// What Chyme can see is assembled **here**, not fetched by the model. The app
/// already knows what is on screen; a model with a tool that can ask for more
/// mail is a model that can ask for all of it, and the difference matters more
/// than the convenience. What it can *do*, though, it does through the same
/// [MailController] the buttons use — one path, one set of rules, and the
/// destructive half of it always asks first.
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
    // Pick up where the last opening left off. A second question almost always
    // refers to the first answer, so starting from nothing made the app forget
    // the thing being asked about.
    _turns.addAll(ChymeMemory.turns);
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
  ///
  /// Each message carries its uid in brackets, because Chyme now acts on
  /// messages and a tool needs to name one. The number is the only handle the
  /// model is given, and it is the one the list is already keyed by.
  String _context(
    MailController controller,
    Preferences prefs,
    FullMessage? open,
  ) {
    if (!prefs.chymeReadsMail) {
      return 'The person has turned off letting you read their mail. You can '
          'still help them write, and still answer questions about the app.';
    }

    final StringBuffer out = StringBuffer();
    final List<MessageSummary> visible = controller.visibleMessages;
    if (visible.isNotEmpty) {
      out.writeln('Their recent mail, newest first:');
      for (final MessageSummary message in visible.take(25)) {
        out.writeln(
          '- [${message.uid}] ${message.fromName} <${message.fromEmail}> · '
          '${message.subject}'
          ' · ${formatListDate(message.date)}'
          '${message.isSeen ? '' : ' · unread'}'
          '${message.isFlagged ? ' · starred' : ''}',
        );
      }
    }

    if (open != null) {
      final String body = open.textBody;
      out
        ..writeln()
        ..writeln('The message they have open, in full:')
        ..writeln('From: ${open.fromName} <${open.fromEmail}>')
        ..writeln('Subject: ${open.subject}')
        ..writeln('Date: ${open.date}')
        ..writeln('--- body ---')
        ..writeln(body.length > 6000 ? body.substring(0, 6000) : body);
    }

    if (out.isEmpty) return 'No mail is loaded at the moment.';
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
          '${Chyme.systemPromptFor(prefs.chymeTone)}\n${_context(controller, prefs, controller.openMessage)}',
        ),
        ..._turns,
      ];

      // A loop, not one request: Chyme asks for something, the app runs it, and
      // the answer goes back into the conversation. Everything that changes
      // anything goes through the controller, so a star from here is the same
      // star as the toolbar's — and the three things that cannot be undone ask
      // their own question before they happen.
      final ChymeRun run = await Chyme.run(
        endpoint: prefs.chymeEndpoint,
        apiKey: prefs.chymeKey,
        model: prefs.chymeModel,
        turns: request,
        tools: _tools(controller),
      );
      if (!mounted) return;
      setState(() {
        _turns.add(ChymeTurn('assistant', run.reply));
        _search = Chyme.searchFrom(run.reply);
        ChymeMemory.remember(_turns);
      });
      _scrollToEnd();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Everything Chyme may do, and what it is told afterwards.
  ///
  /// Read-only tools run silently, because reading is what it was asked to do.
  /// The three that destroy something ask first, and say so when the answer is
  /// no — a model told "declined" stops asking, and a model told nothing tries
  /// again with a different number.
  Map<String, ChymeTool> _tools(MailController controller) {
    return <String, ChymeTool>{
      // The message on screen, in full. The prompt already carries a shortened
      // copy so a question about it needs no tool at all; this is for the long
      // one, where the answer is further down than the excerpt.
      'read': (String argument) async {
        final MessageSummary? summary = _find(controller, argument);
        final FullMessage? open = controller.openMessage;
        if (summary == null && open == null) return 'No message is open.';
        if (summary != null && open != null && summary.uid == open.uid) {
          return _describe(open);
        }
        if (summary == null) return _describe(open!);
        // A row that is not open has no body in memory; opening it is what the
        // person would do, and it is what this does — through the controller,
        // so the reader follows.
        await controller.open(summary);
        final FullMessage? loaded = controller.openMessage;
        if (loaded == null) return 'That message could not be opened.';
        return _describe(loaded);
      },
      'search': (String argument) async {
        final String needle = argument.toLowerCase().trim();
        if (needle.isEmpty) return 'No words to search for.';
        final List<MessageSummary> hits = controller.visibleMessages
            .where(
              (MessageSummary message) =>
                  message.subject.toLowerCase().contains(needle) ||
                  message.fromName.toLowerCase().contains(needle) ||
                  message.fromEmail.toLowerCase().contains(needle),
            )
            .take(8)
            .toList();
        if (hits.isEmpty) {
          final String where = controller.selectedFolder?.name ?? 'this folder';
          return 'Nothing in $where matches "$argument".';
        }
        return hits
            .map((MessageSummary m) =>
                '[${m.uid}] ${m.fromName} — ${m.subject}')
            .join('\n');
      },
      'star': (String argument) async {
        final MessageSummary? message = _find(controller, argument);
        if (message == null) return 'No message with that number.';
        if (message.isFlagged) return 'Already starred: ${message.subject}.';
        await controller.toggleFlag(message);
        return 'Starred "${message.subject}".';
      },
      'unstar': (String argument) async {
        final MessageSummary? message = _find(controller, argument);
        if (message == null) return 'No message with that number.';
        if (!message.isFlagged) return 'Not starred: ${message.subject}.';
        await controller.toggleFlag(message);
        return 'Removed the star from "${message.subject}".';
      },
      'seen': (String argument) async {
        final MessageSummary? message = _find(controller, argument);
        if (message == null) return 'No message with that number.';
        if (message.isSeen) return 'Already read: ${message.subject}.';
        await controller.markRead(message);
        return 'Marked "${message.subject}" read.';
      },
      'archive': (String argument) async {
        final MessageSummary? message = _find(controller, argument);
        if (message == null) return 'No message with that number.';
        await controller.archive(message);
        return 'Archived "${message.subject}".';
      },
      'delete': (String argument) async {
        final MessageSummary? message = _find(controller, argument);
        if (message == null) return 'No message with that number.';
        if (!mounted) return 'The sheet closed; nothing was deleted.';
        final bool yes = await _ask(
          title: 'Delete this message?',
          body: '\u201C${message.subject}\u201D goes to the trash. You can put '
              'it back.',
          confirm: 'Delete',
          cancel: 'Keep',
        );
        if (!yes) return 'The person kept "${message.subject}".';
        await controller.delete(message);
        return 'Moved "${message.subject}" to the trash.';
      },
      'reply': (String argument) async {
        final List<String> parts = argument.split('|');
        final String body = parts.length > 1
            ? parts.sublist(1).join('|').trim()
            : '';
        final MessageSummary? message = _find(controller, parts.first);
        if (message == null) return 'No message with that number.';
        if (body.isEmpty) {
          return 'A reply needs a message number and a body, like: '
              'reply 12 | Thanks, I will look at it today.';
        }
        if (!mounted) return 'The sheet closed; no draft was opened.';
        final FullMessage? open = controller.openMessage;
        final bool threaded = open != null && open.uid == message.uid;
        await openComposeSheet(
          context,
          initialTo: message.fromEmail,
          initialSubject: message.subject.toLowerCase().startsWith('re:')
              ? message.subject
              : 'Re: ${message.subject}',
          initialBody: body,
          inReplyTo: threaded ? open.messageId : null,
          references: threaded ? open.references : null,
        );
        return 'Opened a reply to ${message.fromName}, in their composer, with '
            'that draft. They read it and send it.';
      },
      'contacts': (String argument) async {
        final String needle = argument.trim().toLowerCase();
        if (needle.isEmpty) return 'No name to look for.';
        final List<Contact> hits = Contacts.search(needle).take(8).toList();
        if (hits.isEmpty) return 'Nobody in their contacts matches "$argument".';
        return hits
            .map((Contact c) =>
                '${c.label} <${c.email}>'
                '${c.saved ? ' · saved' : ''}'
                '${Contacts.isBlocked(c.email) ? ' · blocked' : ''}')
            .join('\n');
      },
      'contact_add': (String argument) async {
        final List<String> parts = argument.split('|');
        final String name = parts.first.trim();
        final String email =
            (parts.length > 1 ? parts[1] : parts.first).trim().toLowerCase();
        if (!email.contains('@')) {
          return 'That is not an address. Use: contact_add Name | a@b.com';
        }
        final Contact contact = await Contacts.add(
          email: email,
          name: email == name ? '' : name,
        );
        return 'Saved ${contact.label} <${contact.email}>.';
      },
      'contact_block': (String argument) async {
        final String email = argument.trim().toLowerCase();
        if (!email.contains('@')) return 'That is not an address.';
        if (Contacts.isBlocked(email)) return '$email is already blocked.';
        if (!mounted) return 'The sheet closed; nothing was blocked.';
        final bool yes = await _ask(
          title: 'Block this address?',
          body: 'Mail from $email stops appearing in the list. Nothing is '
              'deleted, and unblocking brings it all back.',
          confirm: 'Block',
          cancel: 'Cancel',
        );
        if (!yes) return 'The person did not block $email.';
        await Contacts.block(email);
        return 'Blocked $email. Their mail is hidden from the list.';
      },
      'contact_delete': (String argument) async {
        final String email = argument.trim().toLowerCase();
        if (!email.contains('@')) return 'That is not an address.';
        if (!mounted) return 'The sheet closed; nothing was removed.';
        final bool yes = await _ask(
          title: 'Forget this contact?',
          body: '$email is removed from your contacts here. Mail from them is '
              'untouched.',
          confirm: 'Forget',
          cancel: 'Cancel',
        );
        if (!yes) return 'The person kept $email.';
        await Contacts.remove(email);
        return 'Removed $email from their contacts.';
      },
    };
  }

  /// The message a tool argument names, or null.
  ///
  /// Tolerant on purpose: a model will write `12`, `#12`, `[12]` and
  /// `uid 12`, and all four mean the same message. "open" means the one on
  /// screen, which is the only name that survives a list that has moved.
  MessageSummary? _find(MailController controller, String argument) {
    final String cleaned = argument.trim().toLowerCase();
    final MessageSummary? open = controller.openSummary;
    if (cleaned == 'open' || cleaned == 'current') return open;
    final String digits = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
    final int? uid = int.tryParse(digits);
    if (uid == null) return open;
    if (open?.uid == uid) return open;
    for (final MessageSummary message in controller.visibleMessages) {
      if (message.uid == uid) return message;
    }
    return null;
  }

  String _describe(FullMessage message) {
    final String body = message.textBody.trim();
    final String html = message.htmlSource ?? '';
    final String text = body.isNotEmpty ? body : html;
    if (text.isEmpty) return 'The message has no readable body.';
    return 'From ${message.fromName} \u2014 ${message.subject}\n\n'
        '${text.length > 6000 ? '${text.substring(0, 6000)}\u2026' : text}';
  }

  /// A question with the detail in it, answered before anything is destroyed.
  Future<bool> _ask({
    required String title,
    required String body,
    required String confirm,
    required String cancel,
  }) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(confirm),
          ),
        ],
      ),
    );
    return yes == true;
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
    final NavigatorState navigator = Navigator.of(context);
    context.read<MailController>().search(query);
    navigator.pop();
    AceSnack.show(context, 'Searching for “$query”');
  }

  /// Starts a reply to the open message with what Chyme wrote in it.
  Future<void> _replyWith(String body) async {
    final MailController controller = context.read<MailController>();
    final MessageSummary? summary = controller.openSummary;
    final FullMessage? open = controller.openMessage;
    if (summary == null) {
      AceSnack.show(context, 'Open a message first — there is nobody to reply to.');
      return;
    }
    await openComposeSheet(
      context,
      initialTo: summary.fromEmail,
      initialSubject: summary.subject.toLowerCase().startsWith('re:')
          ? summary.subject
          : 'Re: ${summary.subject}',
      initialBody: body,
      inReplyTo: open?.messageId,
      references: open?.references,
    );
  }

  /// Settings, opened at the Chyme card rather than at the top of the list.
  Future<void> _openSettings() async {
    final NavigatorState navigator = Navigator.of(context);
    navigator.pop();
    await navigator.push(
      aceRoute(const SettingsScreen(focus: SettingsFocus.chyme)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final Preferences prefs = context.watch<Preferences>();
    final bool configured =
        prefs.chymeEndpoint.trim().isNotEmpty &&
        prefs.chymeModel.trim().isNotEmpty;

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
                      // Chyme arrives rather than being there. A mark that is
                      // simply present reads as an icon; one that lands reads as
                      // something that just turned up, which is what opening
                      // this sheet is.
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: AstryxMotion.of(
                          const Duration(milliseconds: 520),
                        ),
                        curve: Curves.easeOutBack,
                        builder:
                            (BuildContext context, double t, Widget? child) =>
                                Transform.rotate(
                                  angle: (1 - t) * -0.6,
                                  child: Transform.scale(
                                    scale: 0.5 + t * 0.5,
                                    child: child,
                                  ),
                                ),
                        child: ChymeMark(size: 20, color: c.onAccentMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: AstryxSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Chyme',
                          style: AstryxText.heading3(c.textPrimary),
                        ),
                        const SizedBox(height: AstryxSpace.s0_5),
                        // The two settings that change what an answer is, in
                        // the header, one tap from the conversation. Going to
                        // Settings to change the tone and coming back is four
                        // taps to answer a question asked in the middle of
                        // typing.
                        Row(
                          children: <Widget>[
                            _SettingChip(
                              label: prefs.chymeModel.isEmpty
                                  ? 'Choose a model'
                                  : prefs.chymeModel,
                              icon: AceIcons.chyme,
                              onTap: () => chooseChymeModel(context, prefs),
                            ),
                            const SizedBox(width: AstryxSpace.s1_5),
                            _SettingChip(
                              label: prefs.chymeTone.label,
                              icon: AceIcons.signature,
                              onTap: () => chooseChymeTone(context, prefs),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_turns.isNotEmpty)
                    AceIconButton(
                      icon: AceIcons.add,
                      tooltip: 'Start over',
                      onPressed: () => setState(() {
                        _turns.clear();
                        _search = null;
                        _error = null;
                        ChymeMemory.forget();
                      }),
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
                        if (_turns.isEmpty)
                          _suggestions(c, context.read<MailController>()),
                        for (final ChymeTurn turn in _turns)
                          _Bubble(
                            turn: turn,
                            onReply: _replyWith,
                            canReply: context
                                    .watch<MailController>()
                                    .openSummary !=
                                null,
                          ),
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
                            borderRadius: BorderRadius.circular(
                              AstryxRadius.full,
                            ),
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
  Widget _suggestions(AstryxColors c, MailController controller) {
    // Openers that ask for something the app cannot do by itself. "Summarise
    // this" is a button; "what is this actually asking for" is the question
    // somebody opens an assistant with.
    final bool hasOpen = controller.openMessage != null;
    final List<String> prompts = <String>[
      if (hasOpen) 'What is this actually asking me for?',
      if (hasOpen) 'Draft a reply saying I will look at it tomorrow.',
      if (hasOpen) 'Star this and mark it read.',
      'What needs answering today?',
      'Find the last invoice or receipt.',
      'Anything from my bank this week?',
      'Add this sender to my contacts.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Chyme reads the mail in front of you, and can act on it: star, '
          'archive, delete, reply, and keep your contacts. It never sends '
          'anything itself — a reply it writes opens in your composer.',
          style: AstryxText.supporting(c.textSecondary),
        ),
        const SizedBox(height: AstryxSpace.s4),
        for (final String prompt in prompts) ...<Widget>[
          _Opener(label: prompt, onTap: () => _send(prompt)),
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

/// One of the header's two settings, as a chip.
class _SettingChip extends StatelessWidget {
  const _SettingChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final AceIcon icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AstryxRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AstryxSpace.s2,
          vertical: AstryxSpace.s0_5,
        ),
        decoration: BoxDecoration(
          color: c.backgroundMuted,
          borderRadius: BorderRadius.circular(AstryxRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AceIconView(icon: icon, size: 13, color: c.textSecondary),
            const SizedBox(width: AstryxSpace.s1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AstryxText.supporting(c.textSecondary),
              ),
            ),
            AceIconView(
              icon: AceIcons.chevronDown,
              size: 13,
              color: c.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}

/// One turn, as a bubble.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.turn,
    required this.onReply,
    this.canReply = false,
  });

  final ChymeTurn turn;

  /// Opens the composer with this text in it, as a reply to the open message.
  final Future<void> Function(String body) onReply;

  /// Whether there is a message to reply to.
  final bool canReply;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final bool mine = turn.role == 'user';
    final String text = mine
        ? turn.content
        : Chyme.withoutSearchLine(turn.content);

    return Padding(
      padding: const EdgeInsets.only(bottom: AstryxSpace.s3),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          // What Chyme wrote is the useful part, and there are only ever three
          // things anybody wants to do with it: keep it, reply with it, or
          // start a new message with it. All are one tap rather than a
          // selection and a long press.
          if (!mine)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                AceIconButton(
                  icon: AceIcons.copy,
                  tooltip: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) AceSnack.show(context, 'Copied.');
                  },
                ),
                if (canReply)
                  AceIconButton(
                    icon: AceIcons.reply,
                    tooltip: 'Reply with this',
                    onPressed: () => onReply(text),
                  ),
                AceIconButton(
                  icon: AceIcons.edit,
                  tooltip: 'Start a message with this',
                  onPressed: () => openComposeSheet(context, initialBody: text),
                ),
                // Only when the reply asked to delete, and only as a question.
                // A model may propose; the app asks; the person decides.
                if (Chyme.deleteFrom(text))
                  AceIconButton(
                    icon: AceIcons.trash,
                    tooltip: 'Delete this message',
                    onPressed: () => _confirmDelete(context),
                  ),
              ],
            ),
          Row(
            mainAxisAlignment: mine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
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
                  // What Chyme writes is Markdown, and it reads as Markdown when it
                  // is rendered as Markdown. What the person types is not, and is
                  // shown exactly as typed.
                  child: mine
                      ? SelectableText(text, style: AstryxText.body(c.onAccent))
                      : MarkdownView(
                          source: text,
                          onLink: (String url) =>
                              openMarkdownLink(context, url),
                        ),
                ),
              ),
            ],
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
            AceIconView(
              icon: AceIcons.search,
              size: 18,
              color: c.textSecondary,
            ),
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
          ChymeMark(size: 28, color: c.accent),
          const SizedBox(height: AstryxSpace.s4),
          Text(
            'Chyme needs somewhere to ask',
            style: AstryxText.heading3(c.textPrimary),
          ),
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

/// Asks before it deletes, then moves the open message to the trash.
///
/// Chyme cannot delete anything by itself. It can say it would, and this is what
/// happens next: a question with the subject in it, and a way to say no.
/// Everything here is reversible — it goes to the trash, not away.
Future<void> _confirmDelete(BuildContext context) async {
  final MailController controller = context.read<MailController>();
  final MessageSummary? open = controller.openSummary;
  if (open == null) {
    AceSnack.show(context, 'Open the message first — there is nothing to delete.');
    return;
  }
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialog) => AlertDialog(
      title: const Text('Delete this message?'),
      content: Text(
        '\u201C${open.subject}\u201D goes to the trash. You can put it back.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: const Text('Keep'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (yes != true || !context.mounted) return;
  await controller.delete(open);
  if (context.mounted) AceSnack.show(context, 'Moved to the trash.');
}

/// One opener, as a card.
///
/// A chip is a filter; these are questions, and a question wants a row you can
/// read rather than a pill you have to squint at. The mark on the left says who
/// is offering it.
class _Opener extends StatelessWidget {
  const _Opener({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AstryxRadius.element),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AstryxSpace.s3,
          vertical: AstryxSpace.s3,
        ),
        decoration: BoxDecoration(
          color: c.surfaceHighest,
          borderRadius: BorderRadius.circular(AstryxRadius.element),
        ),
        child: Row(
          children: <Widget>[
            ChymeMark(size: 18, color: c.textSecondary),
            const SizedBox(width: AstryxSpace.s3),
            Expanded(
              child: Text(label, style: AstryxText.body(c.textPrimary)),
            ),
            AceIconView(
              icon: AceIcons.chevronRight,
              size: 16,
              color: c.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
