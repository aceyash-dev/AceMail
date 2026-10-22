import 'package:ace_mail/data/mail_providers.dart';
import 'package:ace_mail/models/sign_in_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SignInFormModel', () {
    test('fills the server fields from the provider table as you type', () {
      final SignInFormModel form = SignInFormModel();
      form.username.text = 'someone';
      form.domain = 'gmail.com';
      form.applyProvider();

      expect(form.imapHost.text, 'imap.gmail.com');
      expect(form.imapPort.text, '993');
      expect(form.smtpHost.text, 'smtp.gmail.com');
      expect(form.smtpPort.text, '587');
      form.dispose();
    });

    test('builds a ready account from a known provider', () {
      final SignInFormModel form = SignInFormModel();
      form.username.text = 'someone';
      form.domain = 'gmail.com';
      form.applyProvider();
      form.password.text = 'app-password';

      final SignInOutcome outcome = form.build();

      expect(outcome.isReady, isTrue);
      expect(outcome.error, isNull);
      expect(outcome.account?.email, 'someone@gmail.com');
      expect(outcome.account?.imapHost, 'imap.gmail.com');
      form.dispose();
    });

    test('prefills the address it is given', () {
      final SignInFormModel form = SignInFormModel(initialEmail: 'a@x.com');
      expect(form.email, 'a@x.com');
      form.dispose();
    });

    test('rejects a username that is not a username', () {
      // The domain is a separate control, so an address can no longer be
      // missing its @ — what it can be is an unusable local part.
      final SignInFormModel form = SignInFormModel();
      form.username.text = 'not an address';
      form.password.text = 'p';

      final SignInOutcome outcome = form.build();
      expect(outcome.isReady, isFalse);
      expect(outcome.error, contains('email'));
      form.dispose();
    });

    test('an empty username is asked for by name', () {
      final SignInFormModel form = SignInFormModel();
      form.password.text = 'p';

      expect(form.build().error, contains('username'));
      form.dispose();
    });

    test('rejects an empty password', () {
      final SignInFormModel form = SignInFormModel();
      form.username.text = 'someone';
      form.domain = 'gmail.com';
      form.applyProvider();

      final SignInOutcome outcome = form.build();
      expect(outcome.isReady, isFalse);
      expect(outcome.error, contains('password'));
      form.dispose();
    });

    test('asks for servers, and points at the advanced panel, for an '
        'unknown provider', () {
      final SignInFormModel form = SignInFormModel();
      form.username.text = 'me';
      form.customDomain = true;
      form.domainField.text = 'self-hosted.example';
      form.applyProvider();
      form.password.text = 'p';

      final SignInOutcome outcome = form.build();
      expect(outcome.isReady, isFalse);
      expect(outcome.needsAdvanced, isTrue);
      expect(outcome.error, isNotNull);
      form.dispose();
    });

    test('accepts hand-entered servers for an unknown provider', () {
      final SignInFormModel form = SignInFormModel();
      form.username.text = 'me';
      form.customDomain = true;
      form.domainField.text = 'self-hosted.example';
      form.applyProvider();
      form.password.text = 'p';
      form.imapHost.text = 'imap.self-hosted.example';
      form.smtpHost.text = 'smtp.self-hosted.example';

      final SignInOutcome outcome = form.build();
      expect(outcome.isReady, isTrue);
      expect(outcome.account?.imapHost, 'imap.self-hosted.example');
      expect(outcome.account?.imapPort, 993, reason: 'falls back to the default');
      form.dispose();
    });

    test('a non-numeric port falls back to the default', () {
      final SignInFormModel form = SignInFormModel();
      form.username.text = 'me';
      form.customDomain = true;
      form.domainField.text = 'self-hosted.example';
      form.applyProvider();
      form.password.text = 'p';
      form.imapHost.text = 'imap.self-hosted.example';
      form.smtpHost.text = 'smtp.self-hosted.example';
      form.imapPort.text = 'not-a-port';

      expect(form.build().account?.imapPort, 993);
      form.dispose();
    });
  });

  group('username and domain', () {
    test('the two halves make the address', () {
      final SignInFormModel form = SignInFormModel();
      form.username.text = 'someone';
      form.domain = 'fastmail.com';

      expect(form.email, 'someone@fastmail.com');
      form.dispose();
    });

    test('a half-filled form has no address at all', () {
      final SignInFormModel form = SignInFormModel();
      expect(form.email, isEmpty);
      form.username.text = 'someone';
      expect(form.email, 'someone@gmail.com');
      form.dispose();
    });

    test('a custom domain is used verbatim', () {
      final SignInFormModel form = SignInFormModel();
      form.username.text = 'someone';
      form.customDomain = true;
      form.domainField.text = 'mail.ace-base.cc';

      expect(form.email, 'someone@mail.ace-base.cc');
      form.dispose();
    });

    test('a custom domain fills no servers, so the panel opens', () {
      final SignInFormModel form = SignInFormModel();
      form.username.text = 'someone';
      form.customDomain = true;
      form.domainField.text = 'mail.ace-base.cc';
      form.password.text = 'p';
      form.imapHost.clear();
      form.smtpHost.clear();

      final SignInOutcome outcome = form.build();
      expect(outcome.isReady, isFalse);
      expect(outcome.needsAdvanced, isTrue);
      form.dispose();
    });

    test('picking a provider fills its servers', () {
      final SignInFormModel form = SignInFormModel();
      form.username.text = 'someone';
      form.domain = 'zoho.com';
      form.applyProvider();

      expect(form.imapHost.text, 'imap.zoho.com');
      expect(form.smtpHost.text, 'smtp.zoho.com');
      form.dispose();
    });

    test('an initial address is split into its halves', () {
      final SignInFormModel form = SignInFormModel(initialEmail: 'a@yahoo.in');
      expect(form.username.text, 'a');
      expect(form.domain, 'yahoo.in');
      expect(form.customDomain, isFalse);
      form.dispose();
    });

    test('an unknown initial domain becomes a custom one', () {
      final SignInFormModel form =
          SignInFormModel(initialEmail: 'a@mail.ace-base.cc');
      expect(form.username.text, 'a');
      expect(form.customDomain, isTrue);
      expect(form.domainField.text, 'mail.ace-base.cc');
      form.dispose();
    });

    test('every provider in the picker has servers behind it', () {
      for (final MailProvider provider in kProviderChoices) {
        expect(provider.server, isNotNull, reason: provider.label);
      }
    });

    test('every domain in the picker has servers behind it', () {
      // A provider in the list whose domains are not in the table is a choice
      // that cannot be made: picking it fills in nothing and the sign-in fails
      // with no explanation.
      for (final MailProvider provider in kProviderChoices) {
        for (final String domain in provider.domains) {
          expect(
            kMailProviders[domain],
            isNotNull,
            reason: '$domain is offered but has no IMAP/SMTP settings',
          );
        }
      }
    });

    test('the picker lists each provider once', () {
      final List<String> labels =
          kProviderChoices.map((MailProvider p) => p.label).toList();
      expect(labels.toSet().length, labels.length);
    });

    test('the picker offers only providers that work free with an app password',
        () {
      // The list is short on purpose. A provider here that cannot be reached
      // over IMAP with a free app password is a dead end: the user types a
      // password and only then finds out. So the set is asserted, not its
      // length — a provider quietly re-added has to come with a reason.
      final List<String> labels =
          kProviderChoices.map((MailProvider p) => p.label).toList();
      expect(
        labels,
        <String>['Gmail', 'Yahoo', 'iCloud', 'Zoho', 'GMX', 'Yandex'],
      );
    });
  });
}
