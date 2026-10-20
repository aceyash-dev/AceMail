import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/full_message.dart';
import '../screens/compose_screen.dart';
import '../state/mail_controller.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/dates.dart';
import '../util/files.dart';
import '../util/html_render.dart';
import '../util/routes.dart';
import 'astryx_widgets.dart';
import 'avatar.dart';

class MessageReader extends StatefulWidget {
  const MessageReader({super.key, this.onBack});

  /// Shown only on narrow layouts, where the reader takes the whole screen.
  final VoidCallback? onBack;

  @override
  State<MessageReader> createState() => _MessageReaderState();
}

class _MessageReaderState extends State<MessageReader> {
  bool _plainText = false;

  /// Accumulated horizontal drag, for the swipe-right-to-go-back gesture.
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final MailController controller = context.watch<MailController>();

    if (controller.loadingMessage) {
      return const Center(child: AceLoader());
    }

    final FullMessage? message = controller.openMessage;
    if (message == null) return _placeholder(c);

    return GestureDetector(
      // Swipe right to go back, the way Android gesture navigation works.
      onHorizontalDragStart:
          widget.onBack == null ? null : (DragStartDetails _) => _drag = 0,
      onHorizontalDragUpdate: widget.onBack == null
          ? null
          : (DragUpdateDetails details) =>
              _drag = details.delta.dx > 0 ? _drag + details.delta.dx : 0,
      onHorizontalDragEnd: widget.onBack == null
          ? null
          : (DragEndDetails details) {
              final double velocity = details.primaryVelocity ?? 0;
              if (_drag > 80 || velocity > 300) widget.onBack!.call();
              _drag = 0;
            },
      child: Container(
      color: c.backgroundSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _toolbar(context, c, message),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AstryxSpace.s6,
                0,
                AstryxSpace.s6,
                AstryxSpace.s6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    message.subject,
                    style: AstryxText.heading2(c.textPrimary),
                  ),
                  const SizedBox(height: AstryxSpace.s2),
                  _meta(c, message),
                  if (message.attachments.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AstryxSpace.s4),
                    _attachments(context, c, message),
                  ],
                  const SizedBox(height: AstryxSpace.s4),
                  Divider(height: 1, color: c.border),
                  const SizedBox(height: AstryxSpace.s4),
                  _body(c, message),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _toolbar(BuildContext context, AstryxColors c, FullMessage message) {
    final bool flagged =
        context.watch<MailController>().openSummary?.isFlagged ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AstryxSpace.s4,
        AstryxSpace.s3,
        AstryxSpace.s4,
        AstryxSpace.s2,
      ),
      child: Row(
        children: <Widget>[
          if (widget.onBack != null)
            AceIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: widget.onBack,
            ),
          const Spacer(),
          AceIconButton(
            icon: flagged ? Icons.star_rounded : Icons.star_border_rounded,
            tooltip: flagged ? 'Remove flag' : 'Flag',
            onPressed: () => context.read<MailController>().toggleOpenFlagged(),
          ),
          AceIconButton(
            icon: Icons.mark_email_unread_outlined,
            tooltip: 'Mark as unread',
            onPressed: () {
              context.read<MailController>().markOpenUnread();
              widget.onBack?.call();
            },
          ),
          AceButton(
            label: 'Reply',
            variant: AceButtonVariant.ghost,
            onPressed: () => _reply(context, message),
          ),
          const SizedBox(width: AstryxSpace.s2),
          AceButton(
            label: 'Delete',
            variant: AceButtonVariant.danger,
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  Widget _meta(AstryxColors c, FullMessage message) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        MailAvatar(email: message.fromEmail, name: message.fromName, size: 40),
        const SizedBox(width: AstryxSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                message.fromName,
                style: AstryxText.bodyStrong(c.textPrimary),
              ),
              if (message.fromEmail.isNotEmpty)
                Text(
                  message.fromEmail,
                  style: AstryxText.supporting(c.textSecondary),
                ),
              if (message.toLine.isNotEmpty)
                Text(
                  'To: ${message.toLine}',
                  style: AstryxText.supporting(c.textSecondary),
                ),
              if (message.ccLine.isNotEmpty)
                Text(
                  'Cc: ${message.ccLine}',
                  style: AstryxText.supporting(c.textSecondary),
                ),
              Text(
                formatFullDate(message.date),
                style: AstryxText.supporting(c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _attachments(
    BuildContext context,
    AstryxColors c,
    FullMessage message,
  ) {
    return Wrap(
      spacing: AstryxSpace.s2,
      runSpacing: AstryxSpace.s2,
      children: message.attachments.map((MailAttachment attachment) {
        return Material(
          color: c.accentMuted,
          borderRadius: BorderRadius.circular(AstryxRadius.full),
          child: InkWell(
            borderRadius: BorderRadius.circular(AstryxRadius.full),
            onTap: () => _saveAttachment(context, attachment),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AstryxSpace.s3,
                vertical: AstryxSpace.s2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.attach_file_rounded,
                    size: 15,
                    color: c.textAccent,
                  ),
                  const SizedBox(width: AstryxSpace.s1_5),
                  Text(
                    attachment.fileName,
                    style: AstryxText.label(c.textAccent),
                  ),
                  const SizedBox(width: AstryxSpace.s2),
                  Text(
                    formatBytes(attachment.size),
                    style: AstryxText.supporting(c.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _body(AstryxColors c, FullMessage message) {
    final bool showHtml = message.hasHtml && !_plainText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (message.hasHtml)
          Row(
            children: <Widget>[
              _segmented(
                c,
                label: 'Formatted',
                active: !_plainText,
                onTap: () => setState(() => _plainText = false),
              ),
              const SizedBox(width: AstryxSpace.s2),
              _segmented(
                c,
                label: 'Plain text',
                active: _plainText,
                onTap: () => setState(() => _plainText = true),
              ),
            ],
          ),
        if (message.hasHtml) const SizedBox(height: AstryxSpace.s4),
        if (showHtml)
          _HtmlBody(html: message.htmlBody!)
        else
          SelectableText(
            message.textBody.isEmpty
                ? '(This message has no text.)'
                : message.textBody,
            style: AstryxText.body(c.textPrimary),
          ),
      ],
    );
  }

  Widget _segmented(
    AstryxColors c, {
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active ? c.accent : c.backgroundSurface,
      borderRadius: BorderRadius.circular(AstryxRadius.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(AstryxRadius.full),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AstryxSpace.s3,
            vertical: AstryxSpace.s1_5,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AstryxRadius.full),
            border: Border.all(color: active ? c.accent : c.border),
          ),
          child: Text(
            label,
            style: AstryxText.label(active ? c.onAccent : c.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(AstryxColors c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const BrandMark(size: 56),
          const SizedBox(height: AstryxSpace.s4),
          Text(
            'Select a message to read it.',
            style: AstryxText.body(c.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _reply(BuildContext context, FullMessage message) async {
    final String subject = message.subject.toLowerCase().startsWith('re:')
        ? message.subject
        : 'Re: ${message.subject}';
    await Navigator.of(context).push(
      aceRoute(
        ComposeScreen(
          initialTo: message.fromEmail,
          initialSubject: subject,
          initialBody: '\n\n--- Original message ---\n${message.textBody}',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final MailController controller = context.read<MailController>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text(
          'It will be moved to Trash where your provider has one, '
          'otherwise removed for good.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await controller.deleteOpenMessage();
      widget.onBack?.call();
    }
  }

  Future<void> _saveAttachment(
    BuildContext context,
    MailAttachment attachment,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final String? path = await saveAttachmentFile(
        attachment.fileName,
        attachment.bytes,
      );
      if (path != null) {
        messenger.showSnackBar(SnackBar(content: Text('Saved to $path')));
      }
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $error')));
    }
  }
}

/// Renders an HTML body with [HtmlRenderer], owning the renderer's lifecycle so
/// its link recognisers are released with the widget.
class _HtmlBody extends StatefulWidget {
  const _HtmlBody({required this.html});

  final String html;

  @override
  State<_HtmlBody> createState() => _HtmlBodyState();
}

class _HtmlBodyState extends State<_HtmlBody> {
  HtmlRenderer? _renderer;
  List<InlineSpan> _spans = const <InlineSpan>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebuild();
  }

  @override
  void didUpdateWidget(covariant _HtmlBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) _rebuild();
  }

  void _rebuild() {
    final AstryxColors c = context.astryx;
    _renderer?.dispose();
    final HtmlRenderer renderer = HtmlRenderer(
      baseStyle: AstryxText.body(c.textPrimary),
      linkColor: c.textAccent,
      codeStyle: AstryxText.body(c.textPrimary).copyWith(
        fontFamily: 'monospace',
        fontSize: AstryxType.sSm,
      ),
    );
    _renderer = renderer;
    _spans = renderer.render(widget.html);
  }

  @override
  void dispose() {
    _renderer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Text.rich(TextSpan(children: _spans)),
    );
  }
}
