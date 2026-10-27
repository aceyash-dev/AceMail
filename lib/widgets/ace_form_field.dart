import 'package:flutter/material.dart';

import '../theme/ace_icons.dart';
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
    this.onTap,
    this.readOnly = false,
    this.background,
    this.focusNode,
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

  /// When set, the field is a button in disguise: it opens something instead of
  /// taking typing. The domain picker is the reason this exists.
  final VoidCallback? onTap;

  final bool readOnly;

  /// Overrides the field's fill, for a field that reads as a control rather
  /// than an input.
  final Color? background;

  /// Whose keyboard this is. The composer needs it: the address suggestions
  /// belong to the field that has the cursor, and there is no way to ask a
  /// [TextField] that from outside without one.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    final Widget field = TextField(
      onTap: onTap,
      readOnly: readOnly,
      focusNode: focusNode,
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      autofillHints: autofillHints,
      maxLines: obscure ? 1 : maxLines,
      minLines: minLines,
      onSubmitted: onSubmitted,
      style: AstryxText.body(c.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        errorText: error,
        fillColor: background,
      ),
    );

    // The visible label is decoration; the field itself carries the name, so a
    // screen reader announces "Email address, text field" instead of reading a
    // stray word and then an unnamed box.
    final Widget labelled = Semantics(
      label: label,
      textField: true,
      child: field,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(left: AstryxSpace.s1),
            child: Text(label, style: AstryxText.label(c.textSecondary)),
          ),
        ),
        const SizedBox(height: AstryxSpace.s1_5),
        if (trailing == null)
          labelled
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: labelled),
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
            ? AceIcons.visibility
            : AceIcons.visibilityOff,
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
