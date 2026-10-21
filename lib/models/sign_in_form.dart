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
    if (initialEmail.contains('@')) {
      final int at = initialEmail.indexOf('@');
      username.text = initialEmail.substring(0, at);
      final String rest = initialEmail.substring(at + 1);
      // A known domain selects its provider; anything else is a custom one.
      if (kMailProviders.containsKey(rest)) {
        domain = rest;
      } else {
        customDomain = true;
        domainField.text = rest;
      }
    } else {
      username.text = initialEmail;
    }
    // Fill the server fields as the halves change, so most people never need to
    // open the advanced panel.
    username.addListener(applyProvider);
    domainField.addListener(applyProvider);
    // A manual edit means the servers are the user's, not ours to clear.
    imapHost.addListener(_markHandEdited);
    smtpHost.addListener(_markHandEdited);
    applyProvider();
  }

  final TextEditingController username = TextEditingController();

  /// The manual domain, when [customDomain] is set.
  final TextEditingController domainField = TextEditingController();

  /// The chosen domain, from the picker.
  String domain = 'gmail.com';

  /// True when the user is typing their own domain rather than picking one.
  bool customDomain = false;

  /// The address the two halves make.
  ///
  /// Kept as a getter rather than a third field: the halves are what the user
  /// edits, and an address that could disagree with them is a bug waiting to
  /// happen.
  String get email {
    final String host = customDomain ? domainField.text.trim() : domain;
    final String user = username.text.trim();
    if (user.isEmpty) return '';
    return '$user@$host';
  }

  /// The domains the picker offers, plus a marker for the custom entry.
  static List<String> get domains =>
      <String>[for (final MailProvider p in kProviderChoices) ...p.domains];
  final TextEditingController password = TextEditingController();
  final TextEditingController imapHost = TextEditingController();
  final TextEditingController imapPort = TextEditingController(text: '993');
  final TextEditingController smtpHost = TextEditingController();
  final TextEditingController smtpPort = TextEditingController(text: '587');

  /// Whether the advanced panel is open.
  bool advanced = false;

  /// Whether the password is visible.
  bool obscure = true;

  /// Whether the server fields hold values *we* filled from the provider table.
  bool _autoFilled = false;

  void _markHandEdited() {
    if (!_autoFilled) return;
    _autoFilled = false;
  }

  void applyProvider() {
    final MailServer? server = serverForEmail(email);

    if (server == null) {
      // A domain we do not know. If the servers in the fields came from the
      // provider table, they belong to the *previous* provider and must go:
      // leaving them behind is how "Other" silently signs in to Gmail.
      if (customDomain && _autoFilled) {
        imapHost.clear();
        smtpHost.clear();
        _autoFilled = false;
      }
      return;
    }
    // Writing to the controllers is enough; the fields listen to them, so this
    // needs no setState.
    imapHost.text = server.imapHost;
    imapPort.text = '${server.imapPort}';
    smtpHost.text = server.smtpHost;
    smtpPort.text = '${server.smtpPort}';
    _autoFilled = true;
  }

  /// Whether the address half is usable, or the reason it is not.
  ///
  /// The first step only knows about the address, so it asks only about that.
  String? addressProblem() {
    if (username.text.trim().isEmpty) return 'Enter your username.';
    if (customDomain && domainField.text.trim().isEmpty) {
      return 'Enter your domain.';
    }
    if (MailAddresses.validate(email, field: 'Email') != null) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  /// The account to sign in with, or the reason there isn't one.
  SignInOutcome build() {
    final String address = email;
    // The same validator the compose screen uses, rather than a second,
    // looser opinion about what an address is.
    if (username.text.trim().isEmpty) {
      return const SignInOutcome(error: 'Enter your username.');
    }
    if (customDomain && domainField.text.trim().isEmpty) {
      return const SignInOutcome(error: 'Enter your domain.');
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
    username.removeListener(applyProvider);
    domainField.removeListener(applyProvider);
    imapHost.removeListener(_markHandEdited);
    smtpHost.removeListener(_markHandEdited);
    username.dispose();
    domainField.dispose();
    password.dispose();
    imapHost.dispose();
    imapPort.dispose();
    smtpHost.dispose();
    smtpPort.dispose();
  }
}
