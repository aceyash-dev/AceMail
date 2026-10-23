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
class AceAccount {
  const AceAccount({
    required this.email,
    required this.imapHost,
    required this.imapPort,
    required this.smtpHost,
    required this.smtpPort,
    this.auth = MailAuth.password,
  });

  final String email;
  final String imapHost;
  final int imapPort;
  final String smtpHost;
  final int smtpPort;

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
    String? smtpHost,
    int? smtpPort,
    MailAuth? auth,
  }) =>
      AceAccount(
        email: email ?? this.email,
        imapHost: imapHost ?? this.imapHost,
        imapPort: imapPort ?? this.imapPort,
        smtpHost: smtpHost ?? this.smtpHost,
        smtpPort: smtpPort ?? this.smtpPort,
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
      };

  factory AceAccount.fromJson(Map<String, dynamic> json) => AceAccount(
        email: json['email'] as String,
        imapHost: json['imapHost'] as String,
        imapPort: json['imapPort'] as int,
        smtpHost: json['smtpHost'] as String,
        smtpPort: json['smtpPort'] as int,
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
