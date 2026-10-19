import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/mail_controller.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/files.dart';
import '../widgets/astryx_widgets.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({
    super.key,
    this.initialTo = '',
    this.initialSubject = '',
    this.initialBody = '',
  });

  final String initialTo;
  final String initialSubject;
  final String initialBody;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  late final TextEditingController _to = TextEditingController(
    text: widget.initialTo,
  );
  late final TextEditingController _cc = TextEditingController();
  late final TextEditingController _subject = TextEditingController(
    text: widget.initialSubject,
  );
  late final TextEditingController _body = TextEditingController(
    text: widget.initialBody,
  );

  final List<XFile> _attachments = <XFile>[];
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _to.dispose();
    _cc.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    final List<XFile> picked = await pickAttachmentFiles();
    if (picked.isEmpty) return;
    setState(() => _attachments.addAll(picked));
  }

  Future<void> _send() async {
    if (_to.text.trim().isEmpty) {
      setState(() => _error = 'Add at least one recipient.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<MailController>().send(
            to: _to.text.trim(),
            cc: _cc.text.trim(),
            subject: _subject.text.trim(),
            body: _body.text,
            attachments:
                _attachments.map((XFile file) => File(file.path)).toList(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Message sent.')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Scaffold(
      backgroundColor: c.backgroundBody,
      appBar: AppBar(
        title: const Text('New message'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AstryxSpace.s4),
            child: Center(
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : AceButton(
                      label: 'Send',
                      variant: AceButtonVariant.primary,
                      onPressed: _send,
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(AstryxSpace.s5),
              children: <Widget>[
                _field(
                  label: 'To',
                  controller: _to,
                  hint: 'someone@example.com',
                ),
                const SizedBox(height: AstryxSpace.s3),
                _field(label: 'Cc', controller: _cc, hint: 'optional'),
                const SizedBox(height: AstryxSpace.s3),
                _field(label: 'Subject', controller: _subject, hint: 'Subject'),
                const SizedBox(height: AstryxSpace.s4),
                TextField(
                  controller: _body,
                  minLines: 10,
                  maxLines: 24,
                  style: AstryxText.body(c.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Write your message…',
                  ),
                ),
                const SizedBox(height: AstryxSpace.s4),
                if (_attachments.isNotEmpty) ...<Widget>[
                  Wrap(
                    spacing: AstryxSpace.s2,
                    runSpacing: AstryxSpace.s2,
                    children: _attachments.map((XFile file) {
                      return Chip(
                        label: Text(
                          file.name,
                          style: AstryxText.supporting(c.textPrimary),
                        ),
                        backgroundColor: c.accentMuted,
                        side: BorderSide(color: c.border),
                        onDeleted: () =>
                            setState(() => _attachments.remove(file)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AstryxSpace.s4),
                ],
                Row(
                  children: <Widget>[
                    AceButton(
                      label: 'Attach file',
                      icon: Icons.attach_file_rounded,
                      onPressed: _pickAttachments,
                    ),
                    const Spacer(),
                    AceButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: AstryxSpace.s4),
                  Text(_error!, style: AstryxText.body(c.error)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    final AstryxColors c = context.astryx;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 72,
          child: Text(label, style: AstryxText.body(c.textSecondary)),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            style: AstryxText.body(c.textPrimary),
            decoration: InputDecoration(hintText: hint),
          ),
        ),
      ],
    );
  }
}
