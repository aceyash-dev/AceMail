import 'package:flutter/material.dart';

import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import 'astryx_widgets.dart';

/// A labelled text field, the pattern every form in the app builds by hand.
class AceFormField extends StatelessWidget {
  const AceFormField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.obscure = false,
    this.keyboard,
    this.autofillHints,
    this.maxLines = 1,
    this.minLines,
    this.onSubmitted,
    this.trailing,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? error;
  final bool obscure;
  final TextInputType? keyboard;
  final List<String>? autofillHints;
  final int maxLines;
  final int? minLines;
  final ValueChanged<String>? onSubmitted;

  /// An action that belongs beside the field, such as reveal-password.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    final Widget field = TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      autofillHints: autofillHints,
      maxLines: obscure ? 1 : maxLines,
      minLines: minLines,
      onSubmitted: onSubmitted,
      style: AstryxText.body(c.textPrimary),
      decoration: InputDecoration(hintText: hint, errorText: error),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: AstryxSpace.s1),
          child: Text(label, style: AstryxText.label(c.textSecondary)),
        ),
        const SizedBox(height: AstryxSpace.s1_5),
        if (trailing == null)
          field
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: field),
              const SizedBox(width: AstryxSpace.s2),
              trailing!,
            ],
          ),
      ],
    );
  }
}

/// A password field with a reveal toggle.
class AcePasswordField extends StatelessWidget {
  const AcePasswordField({
    super.key,
    required this.controller,
    required this.obscure,
    required this.onToggleObscure,
    this.label = 'Password',
    this.autofillHints,
  });

  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final String label;
  final List<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return AceFormField(
      label: label,
      controller: controller,
      obscure: obscure,
      autofillHints: autofillHints,
      trailing: AceIconButton(
        icon: obscure
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        tooltip: obscure ? 'Show' : 'Hide',
        onPressed: onToggleObscure,
      ),
    );
  }
}

/// The one place the app shows a failure inline, so a rejected password does
/// not look different depending on which layer rejected it.
class AceErrorBox extends StatelessWidget {
  const AceErrorBox({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AstryxSpace.s4),
      decoration: BoxDecoration(
        color: c.errorMuted,
        borderRadius: BorderRadius.circular(AstryxRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(message, style: AstryxText.supporting(c.onErrorMuted)),
          if (action != null) ...<Widget>[
            const SizedBox(height: AstryxSpace.s3),
            action!,
          ],
        ],
      ),
    );
  }
}
