import 'dart:io';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/limits.dart';
import '../data/preferences.dart';
import '../services/mail_service.dart';
import '../state/mail_controller.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/ace_snack.dart';
import '../util/addresses.dart';
import '../util/attach_plan.dart';
import '../util/files.dart';
import '../widgets/ace_form_field.dart';
import '../widgets/astryx_widgets.dart';
import '../widgets/avatar.dart';
import '../widgets/settings_group.dart';
import '../widgets/ace_icon_view.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({
    super.key,
    this.initialTo = '',
    this.initialCc = '',
    this.initialSubject = '',
    this.initialBody = '',
    this.inReplyTo,
    this.references,
  });

  final String initialTo;
  final String initialCc;
  final String initialSubject;
  final String initialBody;

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

  @override
  void initState() {
    super.initState();
    final Preferences prefs = context.read<Preferences>();
    final String signature = prefs.signature.trim();
    if (signature.isEmpty) return;
    if (widget.initialBody.isEmpty) {
      // A brand-new message starts with the signature.
      _body.text = '\n\n-- \n$signature';
    } else if (prefs.signatureOnReplies) {
      // A reply carries the quoted original below. The signature goes above
      // it, where a signature belongs, rather than after the quote where nobody
      // scrolls to look for it.
      _body.text = '\n\n-- \n$signature${widget.initialBody}';
    }
  }

  @override
  void dispose() {
    _to.dispose();
    _cc.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _attach() async {
    final AttachmentSelection selection = await pickAttachmentFiles();
    final List<File> picked = selection.files;
    if (!mounted) return;
    if (picked.isEmpty) {
      if (selection.rejected > 0) {
        setState(() {
          _error = '${selection.rejected} file(s) were left off: attachments are limited to '
              '${MailLimits.maxOutboundAttachmentBytes ~/ (1024 * 1024)} MB total '
              'and ${MailLimits.maxAttachmentCount} files.';
        });
      }
      return;
    }

    // Sizes are read from the files in bytes, and anything that would push the
    // message past the cap is left off rather than attached and refused later.
    final List<int> sizes = <int>[
      for (final File file in picked) await _sizeOf(file),
    ];
    final AttachPlan plan = planAttachments(
      alreadyBytes: await _totalBytes(),
      sizes: sizes,
      limit: MailLimits.maxOutboundAttachmentBytes,
      alreadyCount: _attachments.length,
      maxCount: MailLimits.maxAttachmentCount,
    );
    final List<File> accepted = <File>[
      for (final int index in plan.accepted) picked[index],
    ];

    if (!mounted) return;
    setState(() {
      _attachments.addAll(accepted);
      final int rejected = selection.rejected + plan.rejected;
      _error = rejected == 0
          ? null
          : '$rejected file(s) were left off: attachments are limited to '
              '${MailLimits.maxOutboundAttachmentBytes ~/ (1024 * 1024)} MB total '
              'and ${MailLimits.maxAttachmentCount} files.';
    });
  }

  Future<int> _sizeOf(File file) async {
    try {
      return await file.length();
    } catch (_) {
      // A file that has moved since it was picked contributes nothing here and
      // will surface on send.
      return 0;
    }
  }

  Future<int> _totalBytes() async {
    int total = 0;
    for (final File file in _attachments) {
      try {
        total += await file.length();
      } catch (_) {
        // The file may have moved; it will surface on send.
      }
    }
    return total;
  }

  /// The accounts the message could go from, and the one it will.
  List<String> get accounts => context.read<MailController>().accountEmails;
  String? _from;

  /// Set once the empty-subject question has been answered, so sending after it
  /// does not ask again.
  bool _warnedAboutSubject = false;

  String? get _chosenFrom =>
      accounts.length > 1 ? (_from ?? accounts.first) : null;

  /// The address the message actually leaves from.
  ///
  /// `_chosenFrom` is null when there is only one account — nothing to choose —
  /// so this falls back to that account. It is what a blind copy to self needs
  /// to name, and it is the same address the transport will stamp on the
  /// message.
  String get _senderEmail => _chosenFrom ?? (accounts.isEmpty ? '' : accounts.first);

  Future<void> _send() async {
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
      // Said before the screen closes. The messenger is the app-wide one, so
      // the bar survives the pop; saying it afterwards would use a context that
      // no longer has a Scaffold.
      AceSnack.show(context, 'Message sent.');
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

    return Scaffold(
      backgroundColor: c.backgroundBody,
      appBar: AppBar(
        title: Text('New message', style: AstryxText.heading3(c.textPrimary)),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AstryxSpace.s3,
              vertical: AstryxSpace.s2,
            ),
            child: AceButton(
              label: _sending ? 'Sending…' : 'Send',
              icon: AceIcons.send,
              variant: AceButtonVariant.primary,
              onPressed: _sending ? null : _send,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AstryxSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Only when there is a choice to make.
              if (accounts.length > 1) ...<Widget>[
                _FromRow(
                  accounts: accounts,
                  selected: _from,
                  onChanged: (String value) => setState(() => _from = value),
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
              AceButton(
                label: 'Attach files',
                icon: AceIcons.attachment,
                onPressed: _sending ? null : _attach,
              ),
            ],
          ),
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

}

/// Which account the message goes from, when there is more than one.
class _FromRow extends StatelessWidget {
  const _FromRow({
    required this.accounts,
    required this.selected,
    required this.onChanged,
  });

  final List<String> accounts;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final String current = selected ?? accounts.first;

    return AceSpringy(
      onTap: () => _pick(context),
      semanticLabel: 'Send from $current',
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
              MailAvatar(email: current, name: current, size: 26, isSelf: true),
              const SizedBox(width: AstryxSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('From', style: AstryxText.label(c.textSecondary)),
                    Text(
                      current,
                      overflow: TextOverflow.ellipsis,
                      style: AstryxText.body(c.textPrimary),
                    ),
                  ],
                ),
              ),
              AceIconView(icon: AceIcons.expandMore, size: 20, color: c.iconSecondary),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pick(BuildContext context) async {
    final String? chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
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
                style: AstryxText.heading3(sheetContext.astryx.textPrimary),
              ),
            ),
            for (final String account in accounts)
              SettingsRow(
                icon: AceIcons.at,
                title: account,
                trailing: account == (selected ?? accounts.first)
                    ? AceIconView(icon: 
                        AceIcons.check,
                        size: 20,
                        color: sheetContext.astryx.accent,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(account),
              ),
            const SizedBox(height: AstryxSpace.s3),
          ],
        ),
      ),
    );
    if (chosen != null) onChanged(chosen);
  }
}
