import 'package:flutter/material.dart';

import '../data/mail_providers.dart';
import '../util/addresses.dart';
import 'ace_account.dart';

/// The result of reading the sign-in form: either an account ready to connect,
/// or the reason we could not build one.
class SignInOutcome {
  const SignInOutcome({this.account, this.error, this.needsAdvanced = false});

  final AceAccount? account;
  final String? error;

  /// True when the missing piece is behind the advanced panel, which the screen
  /// should open so the user can see what to fill in.
  final bool needsAdvanced;

  bool get isReady => account != null;
}

/// The sign-in form's fields, and the rules that turn them into an account.
///
/// All validation, provider lookup and account assembly lives here, so the
/// screen only renders and calls [build]. That is what makes this testable
/// without a widget tree.
class SignInFormModel {
  SignInFormModel({String initialEmail = ''}) {
    email.text = initialEmail;
    // Fill the server fields as the address is typed, so most people never
    // need to open the advanced panel.
    email.addListener(_applyProvider);
    _applyProvider();
  }

  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController imapHost = TextEditingController();
  final TextEditingController imapPort = TextEditingController(text: '993');
  final TextEditingController smtpHost = TextEditingController();
  final TextEditingController smtpPort = TextEditingController(text: '587');

  /// Whether the advanced panel is open.
  bool advanced = false;

  /// Whether the password is visible.
  bool obscure = true;

  void _applyProvider() {
    final MailServer? server = serverForEmail(email.text);
    if (server == null) return;
    // Writing to the controllers is enough; the fields listen to them, so this
    // needs no setState.
    imapHost.text = server.imapHost;
    imapPort.text = '${server.imapPort}';
    smtpHost.text = server.smtpHost;
    smtpPort.text = '${server.smtpPort}';
  }

  /// The account to sign in with, or the reason there isn't one.
  SignInOutcome build() {
    final String address = email.text.trim();
    // The same validator the compose screen uses, rather than a second,
    // looser opinion about what an address is.
    if (address.isEmpty) {
      return const SignInOutcome(error: 'Enter your email address.');
    }
    if (MailAddresses.validate(address, field: 'Email') != null) {
      return const SignInOutcome(error: 'Enter a valid email address.');
    }
    if (password.text.isEmpty) {
      return const SignInOutcome(error: 'Enter your password.');
    }
    if (imapHost.text.trim().isEmpty || smtpHost.text.trim().isEmpty) {
      return const SignInOutcome(
        error: 'Enter the IMAP and SMTP servers for your provider.',
        needsAdvanced: true,
      );
    }

    return SignInOutcome(
      account: AceAccount(
        email: address,
        imapHost: imapHost.text.trim(),
        imapPort: int.tryParse(imapPort.text.trim()) ?? 993,
        smtpHost: smtpHost.text.trim(),
        smtpPort: int.tryParse(smtpPort.text.trim()) ?? 587,
      ),
    );
  }

  void dispose() {
    email.removeListener(_applyProvider);
    email.dispose();
    password.dispose();
    imapHost.dispose();
    imapPort.dispose();
    smtpHost.dispose();
    smtpPort.dispose();
  }
}
