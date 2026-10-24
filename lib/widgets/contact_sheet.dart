import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/contact.dart';
import '../screens/compose_screen.dart';
import '../services/contacts.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/ace_snack.dart';
import '../util/haptics.dart';
import 'ace_icon_view.dart';
import 'astryx_widgets.dart';
import 'avatar.dart';

/// One person: their name, their address, and what you can do about it.
///
/// The button is **Send**, not "Save contact" or "Edit": the reason to open
/// somebody's details in a mail client is almost always to write to them, so
/// that is the one action that gets a filled button. Saving is a decision about
/// the list, and it sits underneath as a quiet one.
class ContactSheet extends StatefulWidget {
  const ContactSheet({super.key, required this.contact});

  final Contact contact;

  @override
  State<ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<ContactSheet> {
  late Contact _contact = widget.contact;
  bool _saving = false;

  Future<void> _toggleSaved() async {
    setState(() => _saving = true);
    unawaited(AceHaptics.select());
    await Contacts.setSaved(_contact.email, !_contact.saved);
    if (!mounted) return;
    setState(() {
      _contact = _contact.copyWith(saved: !_contact.saved);
      _saving = false;
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _contact.email));
    unawaited(AceHaptics.tap());
    if (!mounted) return;
    AceSnack.show(context, 'Address copied');
  }

  Future<void> _send() async {
    unawaited(AceHaptics.tap());
    // The sheet closes first: the composer is a sheet of its own, and stacking
    // one on the other leaves the first behind it when the second is dismissed.
    Navigator.of(context).pop();
    await openComposeSheet(context, initialTo: _contact.email);
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AstryxSpace.s5,
          0,
          AstryxSpace.s5,
          AstryxSpace.s5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            MailAvatar(
              email: _contact.email,
              name: _contact.name,
              size: 72,
            ),
            const SizedBox(height: AstryxSpace.s4),
            Text(
              _contact.label,
              style: AstryxText.heading2(c.textPrimary),
              textAlign: TextAlign.center,
            ),
            if (_contact.hasName) ...<Widget>[
              const SizedBox(height: AstryxSpace.s1),
              SelectableText(
                _contact.email,
                style: AstryxText.body(c.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (_contact.count > 1) ...<Widget>[
              const SizedBox(height: AstryxSpace.s2),
              Text(
                '${_contact.count} messages',
                style: AstryxText.supporting(c.textDisabled),
              ),
            ],
            const SizedBox(height: AstryxSpace.s6),
            Row(
              children: <Widget>[
                Expanded(
                  child: AceButton(
                    label: 'Send',
                    icon: AceIcons.edit,
                    variant: AceButtonVariant.primary,
                    size: AceButtonSize.large,
                    onPressed: _send,
                  ),
                ),
                const SizedBox(width: AstryxSpace.s2),
                AceIconButton(
                  icon: AceIcons.copy,
                  tooltip: 'Copy the address',
                  onPressed: _copy,
                ),
                AceIconButton(
                  icon: _contact.saved ? AceIcons.star : AceIcons.starOff,
                  tooltip: _contact.saved
                      ? 'Forget this contact'
                      : 'Save this contact',
                  selected: _contact.saved,
                  onPressed: _saving ? null : _toggleSaved,
                ),
              ],
            ),
            const SizedBox(height: AstryxSpace.s4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                AceIconView(
                  icon: _contact.saved ? AceIcons.star : AceIcons.user,
                  size: 16,
                  color: c.textDisabled,
                ),
                const SizedBox(width: AstryxSpace.s2),
                Flexible(
                  child: Text(
                    _contact.saved
                        ? 'Saved to your contacts'
                        : 'Seen in your mail, not saved',
                    style: AstryxText.supporting(c.textDisabled),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the sheet for one contact.
Future<void> showContactSheet(BuildContext context, Contact contact) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => ContactSheet(contact: contact),
    );

