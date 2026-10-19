/// Server settings for a mail account. Credentials are kept separate and never
/// live on this object beyond the login call.
class AceAccount {
  const AceAccount({
    required this.email,
    required this.imapHost,
    required this.imapPort,
    required this.smtpHost,
    required this.smtpPort,
  });

  final String email;
  final String imapHost;
  final int imapPort;
  final String smtpHost;
  final int smtpPort;

  String get domain => email.contains('@') ? email.split('@').last : '';

  AceAccount copyWith({
    String? email,
    String? imapHost,
    int? imapPort,
    String? smtpHost,
    int? smtpPort,
  }) =>
      AceAccount(
        email: email ?? this.email,
        imapHost: imapHost ?? this.imapHost,
        imapPort: imapPort ?? this.imapPort,
        smtpHost: smtpHost ?? this.smtpHost,
        smtpPort: smtpPort ?? this.smtpPort,
      );

  Map<String, dynamic> toJson() => {
        'email': email,
        'imapHost': imapHost,
        'imapPort': imapPort,
        'smtpHost': smtpHost,
        'smtpPort': smtpPort,
      };

  factory AceAccount.fromJson(Map<String, dynamic> json) => AceAccount(
        email: json['email'] as String,
        imapHost: json['imapHost'] as String,
        imapPort: json['imapPort'] as int,
        smtpHost: json['smtpHost'] as String,
        smtpPort: json['smtpPort'] as int,
      );
}
