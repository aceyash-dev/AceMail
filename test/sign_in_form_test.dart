import 'package:ace_mail/models/sign_in_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SignInFormModel', () {
    test('fills the server fields from the provider table as you type', () {
      final SignInFormModel form = SignInFormModel();
      form.email.text = 'someone@gmail.com';

      expect(form.imapHost.text, 'imap.gmail.com');
      expect(form.imapPort.text, '993');
      expect(form.smtpHost.text, 'smtp.gmail.com');
      expect(form.smtpPort.text, '587');
      form.dispose();
    });

    test('builds a ready account from a known provider', () {
      final SignInFormModel form = SignInFormModel();
      form.email.text = 'someone@gmail.com';
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
      expect(form.email.text, 'a@x.com');
      form.dispose();
    });

    test('rejects an address with no @', () {
      final SignInFormModel form = SignInFormModel();
      form.email.text = 'not-an-address';
      form.password.text = 'p';

      final SignInOutcome outcome = form.build();
      expect(outcome.isReady, isFalse);
      expect(outcome.error, contains('email'));
      form.dispose();
    });

    test('rejects an empty password', () {
      final SignInFormModel form = SignInFormModel();
      form.email.text = 'someone@gmail.com';

      final SignInOutcome outcome = form.build();
      expect(outcome.isReady, isFalse);
      expect(outcome.error, contains('password'));
      form.dispose();
    });

    test('asks for servers, and points at the advanced panel, for an '
        'unknown provider', () {
      final SignInFormModel form = SignInFormModel();
      form.email.text = 'me@self-hosted.example';
      form.password.text = 'p';

      final SignInOutcome outcome = form.build();
      expect(outcome.isReady, isFalse);
      expect(outcome.needsAdvanced, isTrue);
      expect(outcome.error, isNotNull);
      form.dispose();
    });

    test('accepts hand-entered servers for an unknown provider', () {
      final SignInFormModel form = SignInFormModel();
      form.email.text = 'me@self-hosted.example';
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
      form.email.text = 'me@self-hosted.example';
      form.password.text = 'p';
      form.imapHost.text = 'imap.self-hosted.example';
      form.smtpHost.text = 'smtp.self-hosted.example';
      form.imapPort.text = 'not-a-port';

      expect(form.build().account?.imapPort, 993);
      form.dispose();
    });
  });
}
