import '../models/ace_account.dart';

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

/// One entry in the domain picker: a name to show, the domains it covers, and
/// the provider's own logo.
///
/// Several domains share a provider — yahoo.com and yahoo.in are one mailbox
/// host, as are gmail.com and googlemail.com — so the picker groups them rather
/// than listing a dozen near-identical rows.
class MailProvider {
  const MailProvider(
    this.label,
    this.domains,
    this.logo, {
    this.auth = MailAuth.password,
  });

  final String label;

  /// How this provider signs in. Google is the exception, because Gmail no
  /// longer accepts an app password at all.
  final MailAuth auth;

  /// Whether signing in goes through Google's own screen.
  bool get usesGoogle => auth == MailAuth.google;

  /// Every domain the provider hands out, not just the best-known one.
  final List<String> domains;

  /// The provider's own logo, as a bundled asset.
  ///
  /// The mark belongs to the provider and is used here to say which provider a
  /// row is — which is exactly what a picker is for. The files come from
  /// Wikimedia Commons, which hosts the official artwork. Nothing is drawn by
  /// us: a shape that merely resembles a brand is worse than the brand, because
  /// it is a claim the app cannot back.
  final String logo;

}

/// The providers the picker offers.
///
/// Deliberately short, and shorter than it once was. Every entry is a provider
/// that will actually let this app in: **free**, over IMAP/SMTP, and either
/// with an **app password** or — for Gmail — through **Google's own sign-in**.
/// Offering a provider that cannot work is a dead end the user only discovers
/// after typing a password, which is why the list is this short and why Gmail
/// asks for a Google account rather than a password.
///
/// The ones that were removed, and why, because a short list invites the
/// question:
///
/// * **Outlook, Hotmail, Live** — Microsoft retired basic authentication for
///   personal accounts in September 2024. App passwords no longer work over
///   IMAP, and the account needs OAuth. Microsoft's OAuth is not wired up here
///   the way Google's is: it needs its own client registration, and the flow
///   would have to be written and tested against an account before the provider
///   could honestly be offered.
/// * **Proton** — its IMAP/SMTP bridge is a paid feature, so a free Proton
///   account has no IMAP at all.
/// * **Fastmail** — there is no free tier, and even the paid Basic plan
///   excludes IMAP and app passwords.
/// * **Rediffmail** — IMAP is a paid Rediffmail Pro feature; a free account
///   offers only POP3, which this app does not speak.
///
/// Zoho is kept with a caveat worth knowing: an existing free account can still
/// switch IMAP on, but Zoho has stopped granting IMAP access to newly signed-up
/// free users.
const List<MailProvider> kProviderChoices = <MailProvider>[
  // Google is the one provider here that is not an app password, and the reason
  // is not preference: Gmail stopped accepting app passwords for IMAP and SMTP
  // in 2022. It is also the best sign-in of the lot, because there is no
  // password to issue, store or leak.
  MailProvider('Gmail', <String>['gmail.com', 'googlemail.com'],
      'assets/providers/gmail.svg',
      auth: MailAuth.google),
  MailProvider('Yahoo', <String>['yahoo.com', 'yahoo.in'],
      'assets/providers/yahoo.svg'),
  MailProvider('iCloud', <String>['icloud.com', 'me.com'],
      'assets/providers/icloud.svg'),
  MailProvider('Zoho', <String>['zoho.com', 'zohomail.in'],
      'assets/providers/zoho.svg'),
  MailProvider('GMX', <String>['gmx.com', 'gmx.net'],
      'assets/providers/gmx.svg'),
  MailProvider('Yandex', <String>['yandex.com', 'yandex.ru'],
      'assets/providers/yandex.svg'),
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
  'gmx.com': MailServer(
    imapHost: 'imap.gmx.com',
    imapPort: 993,
    smtpHost: 'mail.gmx.com',
    smtpPort: 587,
  ),
  'gmx.net': MailServer(
    imapHost: 'imap.gmx.net',
    imapPort: 993,
    smtpHost: 'mail.gmx.net',
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
};

MailServer? serverForEmail(String email) {
  final int at = email.indexOf('@');
  if (at < 0) return null;
  return kMailProviders[email.substring(at + 1).toLowerCase().trim()];
}
