import 'dart:async';
import 'dart:io';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/limits.dart';
import '../data/local_store.dart';
import '../data/preferences.dart';
import '../services/chyme.dart';
import '../services/contacts.dart';
import '../services/mail_service.dart';
import '../state/mail_controller.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/ace_snack.dart';
import '../util/addresses.dart';
import '../util/attach_plan.dart';
import '../util/files.dart';
import '../util/text.dart';
import '../widgets/ace_form_field.dart';
import '../widgets/astryx_widgets.dart';
import '../widgets/avatar.dart';
import '../widgets/settings_group.dart';
import '../widgets/ace_icon_view.dart';
import '../data/scheduled.dart';
import '../util/dates.dart';

/// Opens the composer as a sheet.
///
/// A sheet rather than a pushed screen, because writing a message is something
/// you do *over* the mail you were reading: the message you are answering stays
/// behind it, and the sheet is one gesture from being gone. A pushed screen
/// takes the whole display and a back gesture to leave, which is a different
/// promise about how much of your attention it wants.
Future<void> openComposeSheet(
  BuildContext context, {
  String initialTo = '',
  String initialCc = '',
  String initialSubject = '',
  String initialBody = '',
  String? inReplyTo,
  String? references,
  String? from,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) => ComposeScreen(
      initialTo: initialTo,
      initialCc: initialCc,
      initialSubject: initialSubject,
      initialBody: initialBody,
      inReplyTo: inReplyTo,
      references: references,
      from: from,
    ),
  );
}

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({
    super.key,
    this.initialTo = '',
    this.initialCc = '',
    this.initialSubject = '',
    this.initialBody = '',
    this.inReplyTo,
    this.references,
    this.from,
  });

  final String initialTo;
  final String initialCc;
  final String initialSubject;
  final String initialBody;

  /// The account to send from, or null for the automatic choice — the mailbox
  /// the reader is in.
  final String? from;

  /// Threading headers, so a reply lands in the same conversation.
  final String? inReplyTo;
  final String? references;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  late final TextEditingController _to =
      TextEditingController(text: widget.initialTo);
  late final TextEditingController _cc =
      TextEditingController(text: widget.initialCc);
  late final TextEditingController _subject =
      TextEditingController(text: widget.initialSubject);
  late final TextEditingController _body =
      TextEditingController(text: widget.initialBody);

  final List<File> _attachments = <File>[];
  bool _sending = false;
  String? _toError;
  String? _ccError;
  String? _error;

  /// The encrypted store, held rather than read from the context so [dispose]
  /// can still write the draft after the widget is gone.
  LocalStore? _store;
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    final Preferences prefs = context.read<Preferences>();
    final String signature = prefs.signature.trim();
    if (signature.isNotEmpty) {
      if (widget.initialBody.isEmpty) {
        // A brand-new message starts with the signature.
        _body.text = '\n\n-- \n$signature';
      } else if (prefs.signatureOnReplies) {
        // A reply carries the quoted original below. The signature goes above
        // it, where a signature belongs, rather than after the quote where
        // nobody scrolls to look for it.
        _body.text = '\n\n-- \n$signature${widget.initialBody}';
      }
    }

    for (final TextEditingController field in <TextEditingController>[
      _to,
      _cc,
      _subject,
      _body,
    ]) {
      field.addListener(_scheduleDraft);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final LocalStore? store = context.read<LocalStore?>();
    if (identical(store, _store)) return;
    _store = store;
    unawaited(_restoreDraft());
  }

  /// A brand-new message picks up the draft that was left behind. A reply does
  /// not: it already has a body, and filling it from an unrelated draft is how
  /// you send the wrong thing to the wrong person.
  bool get _isBlankCompose =>
      widget.inReplyTo == null &&
      widget.initialTo.isEmpty &&
      widget.initialSubject.isEmpty &&
      widget.initialBody.isEmpty;

  Future<void> _restoreDraft() async {
    final LocalStore? store = _store;
    if (store == null || !_isBlankCompose) return;

    final Map<String, Object?>? draft = await store.loadDraft();
    if (draft == null || !mounted) return;

    setState(() {
      _to.text = draft['to'] as String? ?? _to.text;
      _cc.text = draft['cc'] as String? ?? _cc.text;
      _subject.text = draft['subject'] as String? ?? _subject.text;
      _body.text = draft['body'] as String? ?? _body.text;
    });
    AceSnack.show(context, 'Draft restored');
  }

  void _scheduleDraft() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 1200), _saveDraftNow);
  }

  /// Writes the draft, if there is one worth writing.
  ///
  /// The fields are read **before** the first await, so this is safe to call
  /// from [dispose], where the controllers are about to be torn down.
  void _saveDraftNow() {
    final LocalStore? store = _store;
    if (store == null) return;
    if (_to.text.trim().isEmpty &&
        _subject.text.trim().isEmpty &&
        _body.text.trim().isEmpty) {
      // Nothing to keep, and an empty draft would overwrite a real one.
      return;
    }
    unawaited(
      store.saveDraft(<String, Object?>{
        'to': _to.text,
        'cc': _cc.text,
        'subject': _subject.text,
        'body': _body.text,
        'at': DateTime.now().toIso8601String(),
      }),
    );
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    // Leaving the screen is not throwing the draft away.
    _saveDraftNow();
    _to.dispose();
    _cc.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  /// True while the file picker is open, so a second tap cannot start a second
  /// selection over the same list of attachments.
  bool _pickingAttachments = false;

  Future<void> _attach() async {
    if (_pickingAttachments) return;
    _pickingAttachments = true;
    try {
      final PickedAttachments picked =
          await pickAttachmentFiles(alreadyCount: _attachments.length);
      if (!mounted || picked.files.isEmpty) return;

      // Sizes are read in bytes, and a file that cannot be read is left off
      // rather than attached as an empty one — a failed size check is not the
      // same thing as a zero-byte file.
      final List<File> readable = <File>[];
      final List<int> sizes = <int>[];
      int unreadable = 0;
      for (final File file in picked.files) {
        final int? size = await _sizeOf(file);
        if (size == null) {
          unreadable++;
          continue;
        }
        readable.add(file);
        sizes.add(size);
      }

      // Both caps are applied here, once, and against what the message already
      // carries — an oversized file is skipped individually, so the smaller
      // files picked behind it still attach.
      final AttachPlan plan = planAttachments(
        alreadyBytes: await _totalBytes(),
        alreadyCount: _attachments.length,
        sizes: sizes,
        limit: MailLimits.maxOutboundAttachmentBytes,
        maxCount: MailLimits.maxAttachmentCount,
      );
      final List<File> accepted = <File>[
        for (final int index in plan.accepted) readable[index],
      ];

      if (!mounted) return;
      setState(() {
        _attachments.addAll(accepted);
        _error = _leftOff(
          tooLarge: plan.overSize,
          tooMany: plan.overCount + picked.skipped,
          unreadable: unreadable,
        );
      });
    } finally {
      _pickingAttachments = false;
    }
  }

  /// Says what was left off, and why.
  ///
  /// A file the picker discarded is still the user's file, and a message that
  /// quietly omits one is the failure this whole path exists to prevent — so
  /// every omission is named, not just the size ones.
  String? _leftOff({
    required int tooLarge,
    required int tooMany,
    required int unreadable,
  }) {
    final int total = tooLarge + tooMany + unreadable;
    if (total == 0) return null;
    final List<String> reasons = <String>[
      if (tooLarge > 0)
        '$tooLarge over the '
            '${MailLimits.maxOutboundAttachmentBytes ~/ (1024 * 1024)} MB total',
      if (tooMany > 0)
        '$tooMany over the ${MailLimits.maxAttachmentCount}-file limit',
      if (unreadable > 0) '$unreadable that could not be read',
    ];
    return '$total file(s) were left off: ${reasons.join('; ')}.';
  }

  /// The file's size, or null when it cannot be read.
  Future<int?> _sizeOf(File file) async {
    try {
      return await file.length();
    } catch (_) {
      return null;
    }
  }

  Future<int> _totalBytes() async {
    int total = 0;
    for (final File file in _attachments) {
      total += await _sizeOf(file) ?? 0;
    }
    return total;
  }

  /// The accounts the message could go from, and the one it will.
  List<String> get accounts => context.read<MailController>().accountEmails;

  /// The account chosen by hand, or null for the automatic one.
  late String? _from = widget.from;

  /// The account the app picks on its own: the one being read.
  ///
  /// "Automatic" is not a label for the first entry in a list. It means the
  /// mailbox you are looking at, which is the account a reply belongs to and
  /// the one a message written from this screen most likely means.
  String get _autoFrom {
    final MailController controller = context.read<MailController>();
    return controller.account?.email ??
        (accounts.isEmpty ? '' : accounts.first);
  }

  /// Set once the empty-subject question has been answered, so sending after it
  /// does not ask again.
  bool _warnedAboutSubject = false;

  /// The same, for the attachment question.
  bool _warnedAboutAttachment = false;

  /// One yes/no question, in the shape every confirmation in this app uses.
  Future<bool> _ask({
    required String title,
    required String body,
    required String cancel,
    required String confirm,
  }) async {
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirm),
          ),
        ],
      ),
    );
    return go ?? false;
  }

  /// Asks Chyme to write the message, and puts what it writes in the body.
  ///
  /// It writes into the body rather than sending anything: the reply is a
  /// draft, and a draft is something a person still reads before it leaves.
  Future<void> _writeWithChyme() async {
    final Preferences prefs = context.read<Preferences>();
    final TextEditingController prompt = TextEditingController(
      text: _subject.text.trim().isEmpty ? '' : 'About: ${_subject.text.trim()}',
    );

    final String? asked = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Write with Chyme'),
        content: TextField(
          controller: prompt,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          decoration: const InputDecoration(
            hintText: 'What should it say?',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(prompt.text),
            child: const Text('Write'),
          ),
        ],
      ),
    );
    prompt.dispose();
    if (asked == null || asked.trim().isEmpty || !mounted) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final String written = await Chyme.ask(
        endpoint: prefs.chymeEndpoint,
        apiKey: prefs.chymeKey,
        model: prefs.chymeModel,
        turns: <ChymeTurn>[
          ChymeTurn('system', Chyme.systemPrompt),
          ChymeTurn(
            'user',
            // Asked for the shape as well as the words. A draft with no subject
            // is a draft somebody has to finish before they can send it, and the
            // subject is the one part a model is good at.
            'Write an email. Reply with a line starting "Subject:" and then the '
            'body, with a blank line between them. ${asked.trim()}'
            '${_to.text.trim().isEmpty ? '' : ' It is going to ${_to.text.trim()}.'}',
          ),
        ],
      );
      if (!mounted) return;

      // The subject, when it gave one. A model that ignores the shape still
      // produces a usable body, so a missing subject is not a failure — it is
      // just the old behaviour.
      String body = written;
      String? subject;
      final RegExpMatch? head = RegExp(
        r'^\s*\**Subject\**:\s*(.+)$',
        multiLine: true,
        caseSensitive: false,
      ).firstMatch(written);
      if (head != null) {
        subject = head.group(1)!.replaceAll('*', '').trim();
        body = written.substring(head.end).trim();
      }

      setState(() {
        // Only when there is not one already: somebody who typed a subject has
        // made a decision, and a draft is not allowed to overwrite it.
        if (subject != null &&
            subject.isNotEmpty &&
            _subject.text.trim().isEmpty) {
          _subject.text = subject;
        }
        _body.text = _body.text.trim().isEmpty
            ? body
            : '${_body.text.trim()}\n\n$body';
        _sending = false;
      });
      AceSnack.show(context, 'Chyme wrote a draft — read it before sending.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _sending = false;
      });
    }
  }

  /// The address the message actually leaves from.
  ///
  /// It is what a blind copy to self needs to name, and it is the same address
  /// the transport will stamp on the message.
  String get _senderEmail => _from ?? _autoFrom;

  /// Passed to the transport: null when the choice was automatic, so the
  /// controller sends from the account that is open rather than from a name.
  String? get _chosenFrom => _from;

  Future<void> _send() async {
    // The most common mistake in email: "I've attached the form", and no form.
    if (context.read<Preferences>().warnMissingAttachment &&
        _attachments.isEmpty &&
        mentionsAttachment(_body.text) &&
        !_warnedAboutAttachment) {
      _warnedAboutAttachment = true;
      final bool go = await _ask(
        title: 'Attach something first?',
        body: 'The message mentions an attachment and nothing is attached.',
        cancel: 'Add a file',
        confirm: 'Send anyway',
      );
      if (!go || !mounted) return;
    }

    // A message with no subject is the one people regret, so it asks once.
    if (context.read<Preferences>().warnEmptySubject &&
        _subject.text.trim().isEmpty &&
        !_warnedAboutSubject) {
      _warnedAboutSubject = true;
      final bool go = await showDialog<bool>(
            context: context,
            builder: (BuildContext dialogContext) => AlertDialog(
              title: const Text('Send without a subject?'),
              content: const Text(
                'Recipients will see this as "(no subject)".',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Add one'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Send anyway'),
                ),
              ],
            ),
          ) ??
          false;
      if (!go || !mounted) return;
    }

    final String to = _to.text.trim();
    final String cc = _cc.text.trim();

    final String? toProblem = to.isEmpty
        ? 'Add at least one recipient.'
        : MailAddresses.validate(to, field: 'To');
    final String? ccProblem =
        cc.isEmpty ? null : MailAddresses.validate(cc, field: 'Cc');

    setState(() {
      _toError = toProblem;
      _ccError = ccProblem;
      _error = null;
    });
    if (toProblem != null || ccProblem != null) return;

    final int total = await _totalBytes();
    if (!mounted) return;
    if (total > MailLimits.maxOutboundAttachmentBytes) {
      setState(() {
        _error = 'Attachments are limited to '
            '${MailLimits.maxOutboundAttachmentBytes ~/ (1024 * 1024)} MB.';
      });
      return;
    }

    setState(() => _sending = true);
    try {
      await context.read<MailController>().send(
            to: to,
            cc: cc,
            bcc: context.read<Preferences>().bccSelf ? _senderEmail : '',
            subject: _subject.text,
            body: _body.text,
            attachments: _attachments,
            inReplyTo: widget.inReplyTo,
            references: widget.references,
            fromEmail: _chosenFrom,
          );
      if (!mounted) return;
      // Sent, so the draft is done. Clearing it before the pop also stops
      // [dispose] from writing it straight back.
      _draftTimer?.cancel();
      await _store?.clearDraft();
      if (!mounted) return;
      // Said before the screen closes. The messenger is the app-wide one, so
      // the bar survives the pop; saying it afterwards would use a context that
      // no longer has a Scaffold.
      AceSnack.show(context, 'Message sent.');
      // Saved after it is sent, not before: an address somebody typed and then
      // backed out of is not somebody they write to.
      Contacts.recordSent(<String>[
        ..._to.text.split(','),
        ..._cc.text.split(','),
      ], when: DateTime.now());
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is MailException
            ? error.message
            : 'The message could not be sent.';
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Container(
      // Nearly the whole display, so the message you are answering is a sliver
      // behind it rather than gone.
      height: MediaQuery.sizeOf(context).height * 0.92,
      decoration: BoxDecoration(
        color: c.backgroundBody,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AstryxRadius.sheet),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            const SizedBox(height: AstryxSpace.s3),
            // The grab handle: a sheet is dismissed by dragging it, and this is
            // how that is said without a word.
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(AstryxRadius.full),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AstryxSpace.s5,
                AstryxSpace.s3,
                AstryxSpace.s4,
                AstryxSpace.s1,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'New message',
                      style: AstryxText.heading3(c.textPrimary),
                    ),
                  ),
                  AceIconButton(
                    icon: AceIcons.schedule,
                    tooltip: 'Send later',
                    onPressed: _sending ? null : _sendLater,
                  ),
                  const SizedBox(width: AstryxSpace.s2),
                  AceButton(
                    label: _sending ? 'Sending…' : 'Send',
                    icon: AceIcons.send,
                    variant: AceButtonVariant.primary,
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AstryxSpace.s5,
                  AstryxSpace.s2,
                  AstryxSpace.s5,
                  AstryxSpace.s6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
              // Shown whenever there is an account to name, so "which account
              // does this go from?" always has an answer on screen.
              if (accounts.isNotEmpty) ...<Widget>[
                _FromRow(
                  accounts: accounts,
                  automatic: _autoFrom,
                  selected: _from,
                  onChanged: (String? value) => setState(() => _from = value),
                ),
                const SizedBox(height: AstryxSpace.s3),
              ],
              AceFormField(
                label: 'To',
                controller: _to,
                hint: 'name@example.com',
                error: _toError,
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: AstryxSpace.s3),
              AceFormField(
                label: 'Cc',
                controller: _cc,
                hint: 'optional',
                error: _ccError,
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: AstryxSpace.s3),
              AceFormField(label: 'Subject', controller: _subject),
              const SizedBox(height: AstryxSpace.s4),
              TextField(
                controller: _body,
                maxLines: 14,
                minLines: 8,
                style: AstryxText.body(c.textPrimary),
                decoration: const InputDecoration(hintText: 'Write a message'),
              ),
              const SizedBox(height: AstryxSpace.s4),
              if (_attachments.isNotEmpty) ...<Widget>[
                _attachmentList(c),
                const SizedBox(height: AstryxSpace.s4),
              ],
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: _error == null
                    ? const SizedBox(width: double.infinity)
                    : AceErrorBox(message: _error!),
              ),
              const SizedBox(height: AstryxSpace.s3),
              Row(
                children: <Widget>[
                  AceButton(
                    label: 'Attach files',
                    icon: AceIcons.attachment,
                    onPressed: _sending ? null : _attach,
                  ),
                  if (context.watch<Preferences>().chymeEnabled) ...<Widget>[
                    const SizedBox(width: AstryxSpace.s3),
                    AceButton(
                      label: 'Write with Chyme',
                      icon: AceIcons.chymeWrite,
                      variant: AceButtonVariant.tonal,
                      onPressed: _sending ? null : _writeWithChyme,
                    ),
                  ],
                ],
              ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentList(AstryxColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Attachments', style: AstryxText.label(c.textSecondary)),
        const SizedBox(height: AstryxSpace.s2),
        for (final File file in _attachments)
          Padding(
            padding: const EdgeInsets.only(bottom: AstryxSpace.s1),
            child: Row(
              children: <Widget>[
                AceIconView(icon: AceIcons.attachment, size: 16, color: c.iconSecondary),
                const SizedBox(width: AstryxSpace.s2),
                Expanded(
                  child: Text(
                    file.uri.pathSegments.isEmpty
                        ? file.path
                        : file.uri.pathSegments.last,
                    overflow: TextOverflow.ellipsis,
                    style: AstryxText.supporting(c.textPrimary),
                  ),
                ),
                AceIconButton(
                  icon: AceIcons.close,
                  tooltip: 'Remove',
                  variant: AceIconButtonVariant.standard,
                  onPressed: () => setState(() => _attachments.remove(file)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Queues this message instead of sending it now.
  ///
  /// What is stored is everything needed to send it *without this screen*: the
  /// account, the addresses, the words and the moment. The queue outlives the
  /// app — a message scheduled for tomorrow morning has to survive the phone
  /// being closed and left alone overnight — so nothing here may depend on a
  /// widget still existing.
  Future<void> _sendLater() async {
    final String to = _to.text.trim();
    if (to.isEmpty) {
      setState(() => _error = 'There is nobody to send this to yet.');
      return;
    }
    final DateTime now = DateTime.now();
    final DateTime? at = await _pickMoment(now);
    if (at == null || !mounted) return;

    await Scheduled.add(
      ScheduledSend(
        id: '${now.microsecondsSinceEpoch}',
        account: _senderEmail,
        at: at,
        to: to,
        cc: _cc.text.trim(),
        subject: _subject.text.trim(),
        body: _body.text,
      ),
    );

    // The draft is done, the same as a send: leaving it would mean finding the
    // same message twice.
    _draftTimer?.cancel();
    await _store?.clearDraft();
    if (!mounted) return;
    Navigator.of(context).pop();
    AceSnack.show(context, 'Scheduled for ${formatListDate(at)}.');
  }

  /// A few moments people actually mean, rather than a full date picker.
  ///
  /// "Tomorrow morning" is a decision somebody can make in a second; a calendar
  /// and a time wheel is a decision they make twice.
  Future<DateTime?> _pickMoment(DateTime now) {
    final DateTime tomorrowMorning = DateTime(now.year, now.month, now.day + 1, 8);
    final int daysToMonday = (DateTime.monday - now.weekday + 7) % 7;
    final DateTime nextMonday = DateTime(
      now.year,
      now.month,
      now.day + (daysToMonday == 0 ? 7 : daysToMonday),
      8,
    );

    final List<MapEntry<String, DateTime>> choices = <MapEntry<String, DateTime>>[
      MapEntry<String, DateTime>('In an hour', now.add(const Duration(hours: 1))),
      MapEntry<String, DateTime>('This evening', DateTime(now.year, now.month, now.day, 19)),
      MapEntry<String, DateTime>('Tomorrow morning', tomorrowMorning),
      MapEntry<String, DateTime>('Next Monday', nextMonday),
    ];

    return showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final MapEntry<String, DateTime> choice in choices)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(choice.key),
                subtitle: Text(formatListDate(choice.value)),
                // A moment already gone is not offered: "This evening" at ten at
                // night would queue a message for a time in the past.
                enabled: choice.value.isAfter(now),
                onTap: () => Navigator.of(sheetContext).pop(choice.value),
              ),
          ],
        ),
      ),
    );
  }

}

/// Which account the message goes from, when there is more than one.
class _FromRow extends StatelessWidget {
  const _FromRow({
    required this.accounts,
    required this.automatic,
    required this.selected,
    required this.onChanged,
  });

  final List<String> accounts;

  /// The account the app picks on its own.
  final String automatic;

  /// The account chosen by hand, or null for [automatic].
  final String? selected;

  final ValueChanged<String?> onChanged;

  String get _effective => selected ?? automatic;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return AceSpringy(
      onTap: () => _pick(context),
      semanticLabel: 'Send from $_effective',
      builder: (BuildContext context, double press, bool hover) {
        final double t = press.clamp(0.0, 1.0);
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AstryxSpace.s4,
            vertical: AstryxSpace.s3,
          ),
          decoration: BoxDecoration(
            color: c.backgroundMuted,
            borderRadius: BorderRadius.circular(
              lerpDouble(AstryxRadius.element, AstryxRadius.container, t)!,
            ),
          ),
          child: Row(
            children: <Widget>[
              MailAvatar(
                email: _effective,
                name: _effective,
                size: 26,
                isSelf: true,
              ),
              const SizedBox(width: AstryxSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('From', style: AstryxText.label(c.textSecondary)),
                    Text(
                      _effective,
                      overflow: TextOverflow.ellipsis,
                      style: AstryxText.body(c.textPrimary),
                    ),
                  ],
                ),
              ),
              // One word, so which of the two it is needs no second line.
              if (selected == null)
                Padding(
                  padding: const EdgeInsets.only(right: AstryxSpace.s2),
                  child: Text(
                    'Auto',
                    style: AstryxText.supporting(c.textSecondary),
                  ),
                ),
              AceIconView(
                icon: AceIcons.expandMore,
                size: 20,
                color: c.iconSecondary,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pick(BuildContext context) async {
    // The result is wrapped rather than a bare `String?`: null has to mean
    // "automatic", and a pop with no value means "dismissed". The same value
    // for two different things is how a picker silently changes the sender.
    final _FromChoice? chosen = await showModalBottomSheet<_FromChoice>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final AstryxColors c = sheetContext.astryx;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AstryxSpace.s5,
                  0,
                  AstryxSpace.s5,
                  AstryxSpace.s3,
                ),
                child: Text(
                  'Send from',
                  style: AstryxText.heading3(c.textPrimary),
                ),
              ),
              SettingsRow(
                icon: AceIcons.refresh,
                title: 'Automatic',
                subtitle: automatic,
                trailing: selected == null
                    ? AceIconView(
                        icon: AceIcons.check,
                        size: 20,
                        color: c.accent,
                      )
                    : null,
                onTap: () =>
                    Navigator.of(sheetContext).pop(const _FromChoice(null)),
              ),
              for (final String account in accounts)
                SettingsRow(
                  icon: AceIcons.at,
                  title: account,
                  trailing: account == selected
                      ? AceIconView(
                          icon: AceIcons.check,
                          size: 20,
                          color: c.accent,
                        )
                      : null,
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_FromChoice(account)),
                ),
              const SizedBox(height: AstryxSpace.s3),
            ],
          ),
        );
      },
    );
    if (chosen != null) onChanged(chosen.email);
  }
}

/// A choice from the "send from" sheet. See [_FromRow._pick].
class _FromChoice {
  const _FromChoice(this.email);

  final String? email;

}
