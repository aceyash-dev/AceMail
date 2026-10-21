import 'package:flutter/material.dart';

import '../models/sign_in_form.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import 'ace_form_field.dart';
import 'astryx_widgets.dart';
import 'ace_icon_view.dart';

/// The "Advanced server settings" disclosure and the panel behind it.
///
/// Self-contained: it reads and writes the form model directly, so the sign-in
/// screen does not have to thread six controllers through its build method.
class AdvancedServerPanel extends StatelessWidget {
  const AdvancedServerPanel({
    super.key,
    required this.form,
    required this.onToggle,
  });

  final SignInFormModel form;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AstryxSpace.s1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedRotation(
                  turns: form.advanced ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: AceIconView(icon: 
                    AceIcons.chevronRight,
                    size: 18,
                    color: c.textAccent,
                  ),
                ),
                const SizedBox(width: AstryxSpace.s1),
                Text(
                  'Advanced server settings',
                  style: AstryxText.label(c.textAccent),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: form.advanced ? _panel(context, c) : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _panel(BuildContext context, AstryxColors c) {
    return Padding(
      padding: const EdgeInsets.only(top: AstryxSpace.s3),
      child: AceSurface(
        color: c.backgroundMuted,
        padding: const EdgeInsets.all(AstryxSpace.s4),
        child: Column(
          children: <Widget>[
            AceFormField(
              label: 'IMAP host',
              controller: form.imapHost,
              hint: 'imap.example.com',
            ),
            const SizedBox(height: AstryxSpace.s3),
            Row(
              children: <Widget>[
                Expanded(
                  child: AceFormField(
                    label: 'IMAP port',
                    controller: form.imapPort,
                    keyboard: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AstryxSpace.s3),
                Expanded(
                  child: AceFormField(
                    label: 'SMTP port',
                    controller: form.smtpPort,
                    keyboard: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AstryxSpace.s3),
            AceFormField(
              label: 'SMTP host',
              controller: form.smtpHost,
              hint: 'smtp.example.com',
            ),
          ],
        ),
      ),
    );
  }
}
