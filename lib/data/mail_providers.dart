import 'package:flutter/material.dart';

import '../theme/ace_icons.dart';

/// IMAP/SMTP endpoints for common providers. Anything not listed falls back to
/// the Advanced server settings on the sign-in screen.
class MailServer {
  const MailServer({
    required this.imapHost,
    required this.imapPort,
    required this.smtpHost,
    required this.smtpPort,
  });

  final String imapHost;
  final int imapPort;
  final String smtpHost;
  final int smtpPort;
}

/// One entry in the domain picker: a name to show, and the domains it covers.
///
/// Several domains share a provider — hotmail and live are both Outlook — so the
/// picker groups them rather than listing fifteen near-identical rows.
class MailProvider {
  const MailProvider(
    this.label,
    this.domains,
    this.color,
    this.glyph, {
    this.logo,
  });

  final String label;

  /// Every domain the provider hands out, not just the best-known one. Proton
  /// gives you three and people use all of them.
  final List<String> domains;

  /// The provider's colour, for its tile in the picker.
  ///
  /// A monogram rather than the real brand mark: those are trademarks, and
  /// shipping them would mean shipping licensed assets. A coloured initial says
  /// which provider it is just as quickly and belongs to nobody.
  final Color color;

  /// The mark on the tile.
  ///
  /// Drawn here rather than taken from anyone: a real provider logo is a
  /// trademark and shipping the artwork would mean shipping licensed assets. A
  /// shape that says what kind of provider it is — an envelope, a cloud, a
  /// shield — reads at a glance and belongs to nobody.
  final AceIcon glyph;

  /// The provider's own logo, where we could obtain one.
  ///
  /// These are the providers' marks, used to say which provider a row is —
  /// which is what a picker is for. They come from Wikimedia Commons, which
  /// hosts the official files. Where no logo could be obtained the drawn glyph
  /// stands in, and the row is no worse for it.
  final String? logo;

  MailServer? get server => kMailProviders[domains.first];
}

const List<MailProvider> kProviderChoices = <MailProvider>[
  MailProvider('Gmail', <String>['gmail.com', 'googlemail.com'],
      Color(0xFFEA4335),
      AceIcons.mail, logo: 'assets/providers/gmail.svg'),
  MailProvider('Outlook', <String>['outlook.com', 'hotmail.com', 'live.com'],
      Color(0xFF0078D4),
      AceIcons.mailOpen, logo: 'assets/providers/outlook.svg'),
  MailProvider('Yahoo', <String>['yahoo.com', 'yahoo.in'], Color(0xFF6001D2),
      AceIcons.mailbox, logo: 'assets/providers/yahoo.svg'),
  MailProvider('iCloud', <String>['icloud.com', 'me.com'], Color(0xFF3693F3),
      AceIcons.cloud, logo: 'assets/providers/icloud.svg'),
  MailProvider('Zoho', <String>['zoho.com', 'zohomail.in'], Color(0xFFE42527),
      AceIcons.inbox),
  MailProvider('Fastmail', <String>['fastmail.com'], Color(0xFF0067B9),
      AceIcons.send),
  MailProvider('Proton',
      <String>['proton.me', 'protonmail.com', 'pm.me'], Color(0xFF6D4AFF),
      AceIcons.shield),
  MailProvider('Rediffmail', <String>['rediffmail.com'], Color(0xFFD62B2B), AceIcons.globe, logo: 'assets/providers/rediffmail.svg'),
  MailProvider('GMX', <String>['gmx.com', 'gmx.net'], Color(0xFF1C449B), AceIcons.globe),
  MailProvider('Yandex', <String>['yandex.com', 'yandex.ru'], Color(0xFFFC3F1D), AceIcons.globe, logo: 'assets/providers/yandex.svg'),
];

const Map<String, MailServer> kMailProviders = {
  'gmail.com': MailServer(
    imapHost: 'imap.gmail.com',
    imapPort: 993,
    smtpHost: 'smtp.gmail.com',
    smtpPort: 587,
  ),
  'googlemail.com': MailServer(
    imapHost: 'imap.gmail.com',
    imapPort: 993,
    smtpHost: 'smtp.gmail.com',
    smtpPort: 587,
  ),
  'outlook.com': MailServer(
    imapHost: 'outlook.office365.com',
    imapPort: 993,
    smtpHost: 'smtp.office365.com',
    smtpPort: 587,
  ),
  'hotmail.com': MailServer(
    imapHost: 'outlook.office365.com',
    imapPort: 993,
    smtpHost: 'smtp.office365.com',
    smtpPort: 587,
  ),
  'live.com': MailServer(
    imapHost: 'outlook.office365.com',
    imapPort: 993,
    smtpHost: 'smtp.office365.com',
    smtpPort: 587,
  ),
  'yahoo.com': MailServer(
    imapHost: 'imap.mail.yahoo.com',
    imapPort: 993,
    smtpHost: 'smtp.mail.yahoo.com',
    smtpPort: 587,
  ),
  'yahoo.in': MailServer(
    imapHost: 'imap.mail.yahoo.com',
    imapPort: 993,
    smtpHost: 'smtp.mail.yahoo.com',
    smtpPort: 587,
  ),
  'icloud.com': MailServer(
    imapHost: 'imap.mail.me.com',
    imapPort: 993,
    smtpHost: 'smtp.mail.me.com',
    smtpPort: 587,
  ),
  'me.com': MailServer(
    imapHost: 'imap.mail.me.com',
    imapPort: 993,
    smtpHost: 'smtp.mail.me.com',
    smtpPort: 587,
  ),
  'zoho.com': MailServer(
    imapHost: 'imap.zoho.com',
    imapPort: 993,
    smtpHost: 'smtp.zoho.com',
    smtpPort: 587,
  ),
  'zohomail.in': MailServer(
    imapHost: 'imap.zoho.in',
    imapPort: 993,
    smtpHost: 'smtp.zoho.in',
    smtpPort: 587,
  ),
  'pm.me': MailServer(
    imapHost: 'imap.proton.me',
    imapPort: 993,
    smtpHost: 'smtp.proton.me',
    smtpPort: 465,
  ),
  'gmx.com': MailServer(
    imapHost: 'imap.gmx.com',
    imapPort: 993,
    smtpHost: 'smtp.gmx.com',
    smtpPort: 587,
  ),
  'gmx.net': MailServer(
    imapHost: 'imap.gmx.net',
    imapPort: 993,
    smtpHost: 'smtp.gmx.net',
    smtpPort: 587,
  ),
  'yandex.com': MailServer(
    imapHost: 'imap.yandex.com',
    imapPort: 993,
    smtpHost: 'smtp.yandex.com',
    smtpPort: 465,
  ),
  'yandex.ru': MailServer(
    imapHost: 'imap.yandex.ru',
    imapPort: 993,
    smtpHost: 'smtp.yandex.ru',
    smtpPort: 465,
  ),
  'rediffmail.com': MailServer(
    imapHost: 'imap.rediff.com',
    imapPort: 993,
    smtpHost: 'smtp.rediffmail.com',
    smtpPort: 587,
  ),
  'fastmail.com': MailServer(
    imapHost: 'imap.fastmail.com',
    imapPort: 993,
    smtpHost: 'smtp.fastmail.com',
    smtpPort: 587,
  ),
  // Proton Mail via the desktop Bridge.
  'protonmail.com': MailServer(
    imapHost: '127.0.0.1',
    imapPort: 1143,
    smtpHost: '127.0.0.1',
    smtpPort: 1025,
  ),
  'proton.me': MailServer(
    imapHost: '127.0.0.1',
    imapPort: 1143,
    smtpHost: '127.0.0.1',
    smtpPort: 1025,
  ),
};

MailServer? serverForEmail(String email) {
  final int at = email.indexOf('@');
  if (at < 0) return null;
  return kMailProviders[email.substring(at + 1).toLowerCase().trim()];
}
