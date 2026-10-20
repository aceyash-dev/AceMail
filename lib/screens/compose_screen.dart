import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/limits.dart';
import '../services/mail_service.dart';
import '../state/mail_controller.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/addresses.dart';
import '../util/files.dart';
import '../widgets/astryx_widgets.dart';

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
  void dispose() {
    _to.dispose();
    _cc.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _attach() async {
    final List<File> picked = await pickAttachmentFiles();
    if (!mounted || picked.isEmpty) return;

    final int total = await _totalBytes();
    setState(() {
      _attachments.addAll(picked);
      if (total + picked.fold<int>(0, (int sum, File f) => sum + f.path.length) >
          MailLimits.maxOutboundAttachmentBytes) {
        _error = 'Attachments are limited to '
            '${MailLimits.maxOutboundAttachmentBytes ~/ (1024 * 1024)} MB.';
      }
    });
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

  Future<void> _send() async {
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
            subject: _subject.text,
            body: _body.text,
            attachments: _attachments,
            inReplyTo: widget.inReplyTo,
            references: widget.references,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Message sent.')),
      );
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
              icon: Icons.send_rounded,
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
              _field('To', _to, hint: 'name@example.com', error: _toError),
              const SizedBox(height: AstryxSpace.s3),
              _field('Cc', _cc, hint: 'optional', error: _ccError),
              const SizedBox(height: AstryxSpace.s3),
              _field('Subject', _subject),
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
                    : _errorBox(c, _error!),
              ),
              const SizedBox(height: AstryxSpace.s3),
              AceButton(
                label: 'Attach files',
                icon: Icons.attach_file_rounded,
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
                Icon(Icons.attach_file_rounded, size: 16, color: c.iconSecondary),
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
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 16, color: c.iconSecondary),
                  tooltip: 'Remove',
                  onPressed: () => setState(() => _attachments.remove(file)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _errorBox(AstryxColors c, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AstryxSpace.s3),
      decoration: BoxDecoration(
        color: c.errorMuted,
        borderRadius: BorderRadius.circular(AstryxRadius.element),
      ),
      child: Text(message, style: AstryxText.supporting(c.error)),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    String? error,
  }) {
    final AstryxColors c = context.astryx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AstryxText.label(c.textSecondary)),
        const SizedBox(height: AstryxSpace.s1_5),
        TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          style: AstryxText.body(c.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            errorText: error,
          ),
        ),
      ],
    );
  }
}
