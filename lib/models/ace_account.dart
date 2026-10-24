/// How an account proves who it is.
///
/// Two, and the difference is not cosmetic: one is a secret the provider issued
/// and the app stores, and the other is a token that expires in an hour and is
/// fetched again each time. An account that signs in with Google has **no
/// stored secret at all**, which is why this is on the account rather than
/// inferred from whether a password happens to be in the keychain.
enum MailAuth {
  /// A password — in practice, an app password the provider issued.
  password,

  /// Google's OAuth. The only way Gmail accepts a connection now.
  google,
}

/// Server settings for a mail account. Credentials are kept separate and never
/// live on this object beyond the login call.
/// How a connection is made secure.
///
/// Two modes, and no third. There is no "plain" here on purpose: this app never
/// sends a password over an unencrypted connection, so a server that will not
/// encrypt is refused rather than downgraded — see [MailSecurity.forPort].
enum MailSecurity {
  /// TLS from the first byte. Ports 993 (IMAP) and 465 (SMTP).
  implicitTls,

  /// Starts plain and is upgraded before anything is sent. Everything else.
  startTls;

  /// The mode a port implies.
  ///
  /// The two standard ports speak TLS immediately and every other port is
  /// expected to offer STARTTLS. This is the provider default, and it is why an
  /// account saved before this setting existed reads back correctly: a missing
  /// value is inferred from the port it is connecting to.
  static MailSecurity forPort(int port) =>
      (port == 993 || port == 465) ? implicitTls : startTls;

  static MailSecurity fromName(String? name) {
    for (final MailSecurity value in MailSecurity.values) {
      if (value.name == name) return value;
    }
    return implicitTls;
  }
}

class AceAccount {
  const AceAccount({
    required this.email,
    required this.imapHost,
    required this.imapPort,
    this.imapSecurity,
    required this.smtpHost,
    required this.smtpPort,
    this.smtpSecurity,
    this.auth = MailAuth.password,
  });

  final String email;
  final String imapHost;
  final int imapPort;

  /// How this server is secured, or null to take the port's word for it.
  final MailSecurity? imapSecurity;
  final String smtpHost;
  final int smtpPort;

  /// See [imapSecurity].
  final MailSecurity? smtpSecurity;

  /// The mode to connect to IMAP with: the setting, or what the port implies.
  MailSecurity get imapTransport => imapSecurity ?? MailSecurity.forPort(imapPort);

  /// See [imapTransport].
  MailSecurity get smtpTransport => smtpSecurity ?? MailSecurity.forPort(smtpPort);

  /// How this account signs in. Defaults to a password, which is what every
  /// account stored before this existed used.
  final MailAuth auth;

  /// Whether this account signs in with Google, and therefore has no password
  /// to ask for and nothing to store.
  bool get isGoogle => auth == MailAuth.google;

  String get domain => email.contains('@') ? email.split('@').last : '';

  AceAccount copyWith({
    String? email,
    String? imapHost,
    int? imapPort,
    MailSecurity? imapSecurity,
    bool clearImapSecurity = false,
    String? smtpHost,
    int? smtpPort,
    MailSecurity? smtpSecurity,
    bool clearSmtpSecurity = false,
    MailAuth? auth,
  }) =>
      AceAccount(
        email: email ?? this.email,
        imapHost: imapHost ?? this.imapHost,
        imapPort: imapPort ?? this.imapPort,
        imapSecurity:
            clearImapSecurity ? null : (imapSecurity ?? this.imapSecurity),
        smtpHost: smtpHost ?? this.smtpHost,
        smtpPort: smtpPort ?? this.smtpPort,
        smtpSecurity:
            clearSmtpSecurity ? null : (smtpSecurity ?? this.smtpSecurity),
        auth: auth ?? this.auth,
      );

  Map<String, dynamic> toJson() => {
        'email': email,
        'imapHost': imapHost,
        'imapPort': imapPort,
        'smtpHost': smtpHost,
        'smtpPort': smtpPort,
        // Written only when it is not the default, so records saved before this
        // existed read back unchanged.
        if (auth != MailAuth.password) 'auth': auth.name,
        // Written only when it differs from what the port implies, so an
        // account saved before this setting existed reads back identically —
        // and a record that never needed the setting never grows one.
        if (imapSecurity != null && imapSecurity != MailSecurity.forPort(imapPort))
          'imapSecurity': imapSecurity.name,
        if (smtpSecurity != null && smtpSecurity != MailSecurity.forPort(smtpPort))
          'smtpSecurity': smtpSecurity.name,
      };

  factory AceAccount.fromJson(Map<String, dynamic> json) => AceAccount(
        email: json['email'] as String,
        imapHost: json['imapHost'] as String,
        imapPort: json['imapPort'] as int,
        smtpHost: json['smtpHost'] as String,
        smtpPort: json['smtpPort'] as int,
        // Absent means "the port's word for it", which is what every account
        // saved before this existed gets.
        imapSecurity: json['imapSecurity'] == null
            ? null
            : MailSecurity.fromName(json['imapSecurity'] as String),
        smtpSecurity: json['smtpSecurity'] == null
            ? null
            : MailSecurity.fromName(json['smtpSecurity'] as String),
        auth: _authFrom(json['auth'] as String?),
      );

  /// An unknown or absent value is a password: it is what every account was
  /// before this existed, and a record that cannot be read is worse than one
  /// read as the older thing.
  static MailAuth _authFrom(String? name) {
    for (final MailAuth value in MailAuth.values) {
      if (value.name == name) return value;
    }
    return MailAuth.password;
  }
}
