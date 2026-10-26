import 'dart:convert';

import 'package:ace_mail/data/mail_providers.dart';
import 'package:ace_mail/models/ace_account.dart';
import 'package:ace_mail/models/sign_in_form.dart';
import 'package:ace_mail/services/google_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google sign-in, minus the part that needs a Google account.
void main() {
  group('the provider table', () {
    test('Gmail signs in with Google, and the rest with a password', () {
      final MailProvider gmail = kProviderChoices
          .firstWhere((MailProvider p) => p.domains.contains('gmail.com'));
      expect(gmail.usesGoogle, isTrue);
      expect(gmail.auth, MailAuth.google);

      for (final MailProvider provider in kProviderChoices) {
        if (provider.domains.contains('gmail.com')) continue;
        expect(provider.usesGoogle, isFalse, reason: provider.label);
        expect(provider.auth, MailAuth.password, reason: provider.label);
      }
    });

    test('both Google domains are covered', () {
      final MailProvider gmail = kProviderChoices
          .firstWhere((MailProvider p) => p.usesGoogle);
      expect(gmail.domains, contains('googlemail.com'));
    });
  });

  group('the account record', () {
    test('an account with no auth field is a password account', () {
      // Every account saved before Google sign-in existed has no such field,
      // and has to keep working.
      final AceAccount account = AceAccount.fromJson(<String, dynamic>{
        'email': 'a@example.com',
        'imapHost': 'imap.example.com',
        'imapPort': 993,
        'smtpHost': 'smtp.example.com',
        'smtpPort': 587,
      });
      expect(account.auth, MailAuth.password);
      expect(account.isGoogle, isFalse);
    });

    test('an unknown auth value falls back to a password', () {
      final AceAccount account = AceAccount.fromJson(<String, dynamic>{
        'email': 'a@example.com',
        'imapHost': 'imap.example.com',
        'imapPort': 993,
        'smtpHost': 'smtp.example.com',
        'smtpPort': 587,
        'auth': 'something-from-a-newer-build',
      });
      expect(account.auth, MailAuth.password);
    });

    test('a Google account round-trips, and is written explicitly', () {
      const AceAccount account = AceAccount(
        email: 'a@gmail.com',
        imapHost: 'imap.gmail.com',
        imapPort: 993,
        smtpHost: 'smtp.gmail.com',
        smtpPort: 587,
        auth: MailAuth.google,
      );
      expect(jsonEncode(account.toJson()), contains('"auth":"google"'));
      expect(AceAccount.fromJson(account.toJson()).auth, MailAuth.google);
      expect(AceAccount.fromJson(account.toJson()).isGoogle, isTrue);
    });

    test('a password account does not write the field at all', () {
      const AceAccount account = AceAccount(
        email: 'a@example.com',
        imapHost: 'imap.example.com',
        imapPort: 993,
        smtpHost: 'smtp.example.com',
        smtpPort: 587,
      );
      expect(account.toJson().containsKey('auth'), isFalse);
    });
  });

  group('the sign-in form', () {
    test('knows a Google address when it sees one', () {
      final SignInFormModel form = SignInFormModel()
        ..username.text = 'someone'
        ..domain = 'gmail.com';
      expect(form.isGoogle, isTrue);

      final SignInFormModel other = SignInFormModel()
        ..username.text = 'someone'
        ..domain = 'yahoo.com';
      expect(other.isGoogle, isFalse);
    });

    test('does not ask a Google address for a password', () {
      final SignInFormModel form = SignInFormModel()
        ..username.text = 'someone'
        ..domain = 'gmail.com'
        ..applyProvider();
      // No password typed, and the form still builds.
      final SignInOutcome outcome = form.build();
      expect(outcome.account, isNotNull);
      expect(outcome.account!.auth, MailAuth.google);
      expect(outcome.account!.imapHost, 'imap.gmail.com');
    });

    test('still asks anyone else for a password', () {
      final SignInFormModel form = SignInFormModel()
        ..username.text = 'someone'
        ..domain = 'yahoo.com'
        ..applyProvider();
      expect(form.build().error, 'Enter your password.');
    });

    test('builds the account for whichever address Google returned', () {
      final SignInFormModel form = SignInFormModel();
      // Not what was typed on the first step: the account that authorised is
      // the one that has to be added.
      final AceAccount? account = form.googleAccount('other@gmail.com');
      expect(account, isNotNull);
      expect(account!.email, 'other@gmail.com');
      expect(account.auth, MailAuth.google);
      expect(account.imapHost, 'imap.gmail.com');
      expect(account.smtpPort, 587);
    });

    test('refuses an address it has no servers for', () {
      final SignInFormModel form = SignInFormModel();
      expect(form.googleAccount('someone@unknown.example'), isNull);
      expect(form.googleAccount('not-an-address'), isNull);
    });
  });

  group('what a failure says', () {
    test('cancelling says so, and points at the other cause', () {
      final String said = GoogleAuth.describe(const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      ));
      expect(said, startsWith('Sign-in was cancelled.'));
      // "Cancelled" is also what Credential Manager reports when it could not
      // produce a credential at all, so the message has to name that second
      // possibility rather than send somebody looking for a sheet they closed.
      expect(said, contains('not registered with Google'));
    });

    test("Google's own description is kept when there is one", () {
      // The only thing that separates a real cancellation from a
      // configuration fault is what Google put in the description.
      final String said = GoogleAuth.describe(const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'No credential available.',
      ));
      expect(said, contains('No credential available.'));
    });

    test('a configuration failure names the cause', () {
      final String said = GoogleAuth.describe(const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
      ));
      // The plugin's own message does not say what to check; this one has to,
      // because it is the failure a developer will actually hit.
      expect(said, contains('signing certificate'));
      expect(said, contains('web one'));
    });

    test('every code has something to say', () {
      for (final GoogleSignInExceptionCode code
          in GoogleSignInExceptionCode.values) {
        final String said =
            GoogleAuth.describe(GoogleSignInException(code: code));
        expect(said, isNotEmpty, reason: code.name);
        expect(said.trim(), said, reason: code.name);
      }
    });

    test('the client id is the project the app is registered under', () {
      expect(GoogleAuth.clientId, endsWith('.apps.googleusercontent.com'));
      // The full-access scope, which is the only one XOAUTH2 accepts.
      expect(GoogleAuth.scopes, <String>['https://mail.google.com/']);
    });
  });
}
