import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../services/contacts.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import 'ace_icon_view.dart';
import 'astryx_widgets.dart';
import 'avatar.dart';
import 'contact_sheet.dart';

/// Everyone the app has seen, and everyone saved.
///
/// A list, not a directory: the addresses in it came from the mail, so it
/// arrives already full of the people who actually write to you, and the ones
/// you chose to keep are marked and float to the top.
class ContactsPanel extends StatefulWidget {
  const ContactsPanel({super.key, this.query = ''});

  /// The search, owned by the screen above so the app bar's search bar is the
  /// one search bar on the page.
  final String query;

  @override
  State<ContactsPanel> createState() => _ContactsPanelState();
}

class _ContactsPanelState extends State<ContactsPanel> {
  @override
  void initState() {
    super.initState();
    // Reading the file is quick, but it is still a file: the first frame draws
    // without it and the list arrives a moment later.
    Contacts.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final List<Contact> contacts = Contacts.search(widget.query);

    if (contacts.isEmpty) {
      return _Empty(query: widget.query);
    }

    final int saved = contacts.where((Contact contact) => contact.saved).length;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AstryxSpace.s3,
        AstryxSpace.s2,
        AstryxSpace.s3,
        // Room for the floating bar, so the last row is not under it.
        AstryxSpace.s12 + AstryxSpace.s8,
      ),
      itemCount: contacts.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AstryxSpace.s2,
              AstryxSpace.s2,
              AstryxSpace.s2,
              AstryxSpace.s3,
            ),
            child: Text(
              saved == 0
                  ? '${contacts.length} ${contacts.length == 1 ? 'address' : 'addresses'} from your mail'
                  : '$saved saved · ${contacts.length} in all',
              style: AstryxText.supporting(c.textSecondary),
            ),
          );
        }

        final Contact contact = contacts[index - 1];
        return _ContactRow(contact: contact);
      },
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return AceSpringy(
      onTap: () => showContactSheet(context, contact),
      builder: (BuildContext context, double press, bool hover) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(
            horizontal: AstryxSpace.s3,
            vertical: AstryxSpace.s2,
          ),
          decoration: BoxDecoration(
            color: hover ? c.surfaceHighest : Colors.transparent,
            borderRadius: BorderRadius.circular(AstryxRadius.container),
          ),
          child: Row(
            children: <Widget>[
              MailAvatar(
                email: contact.email,
                name: contact.name,
                size: 40,
              ),
              const SizedBox(width: AstryxSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      contact.label,
                      style: AstryxText.body(c.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (contact.hasName)
                      Text(
                        contact.email,
                        style: AstryxText.supporting(c.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (contact.saved)
                AceIconView(
                  icon: AceIcons.star,
                  size: 18,
                  color: c.accent,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final bool searching = query.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AstryxSpace.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AceIconView(
              icon: searching ? AceIcons.filterOff : AceIcons.user,
              size: 40,
              color: c.iconDisabled,
            ),
            const SizedBox(height: AstryxSpace.s4),
            Text(
              searching ? 'Nobody matches “$query”' : 'No addresses yet',
              style: AstryxText.heading3(c.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AstryxSpace.s2),
            Text(
              searching
                  ? 'Try fewer letters, or an address.'
                  : 'Addresses appear here as mail loads — everyone who writes '
                      'to you, and everyone you write to.',
              style: AstryxText.body(c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

