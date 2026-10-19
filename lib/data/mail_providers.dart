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
