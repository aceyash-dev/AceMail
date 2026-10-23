import 'dart:convert';
import 'dart:math';

import 'package:ace_mail/services/google_auth.dart';
import 'package:ace_mail/services/google_desktop_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// A token with the given payload. The header and signature are never read, so
/// they only need to be present, not real.
String _idToken(Map<String, Object?> claims) {
  final String payload =
      base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '');
  return 'eyJhbGciOiJSUzI1NiJ9.$payload.signature';
}

void main() {
  group('PKCE (RFC 7636)', () {
    test('the verifier is 43 URL-safe characters', () {
      final PkcePair pair = PkceFactory.create(Random(7));
      expect(pair.verifier.length, 43);
      expect(RegExp(r'^[A-Za-z0-9\-_]+$').hasMatch(pair.verifier), isTrue);
    });

    test('the challenge is the unpadded base64url SHA-256 of the verifier', () {
      final PkcePair pair = PkceFactory.create(Random(7));
      final String expected = base64UrlEncode(
        sha256.convert(utf8.encode(pair.verifier)).bytes,
      ).replaceAll('=', '');
      expect(pair.challenge, expected);
    });

    test('different randomness gives a different verifier', () {
      final PkcePair a = PkceFactory.create(Random(1));
      final PkcePair b = PkceFactory.create(Random(2));
      expect(a.verifier, isNot(b.verifier));
    });
  });

  group('authorisation URL', () {
    final Uri url = GoogleDesktopAuth.authorisationUrl(
      redirectUri: 'http://127.0.0.1:53000/',
      state: 'state-abc',
      codeChallenge: 'challenge-xyz',
      clientId: 'client.apps.googleusercontent.com',
    );

    test('goes to Google accounts over HTTPS', () {
      expect(url.scheme, 'https');
      expect(url.host, 'accounts.google.com');
      expect(url.path, '/o/oauth2/v2/auth');
    });

    test('asks for a code with PKCE and a state', () {
      expect(url.queryParameters['response_type'], 'code');
      expect(url.queryParameters['code_challenge'], 'challenge-xyz');
      expect(url.queryParameters['code_challenge_method'], 'S256');
      expect(url.queryParameters['state'], 'state-abc');
    });

    test('asks for offline access and consent, so a refresh token is issued', () {
      expect(url.queryParameters['access_type'], 'offline');
      expect(url.queryParameters['prompt'], 'consent');
    });

    test('redirects to the loopback address it was given', () {
      expect(url.queryParameters['redirect_uri'], 'http://127.0.0.1:53000/');
      expect(url.queryParameters['client_id'], 'client.apps.googleusercontent.com');
    });

    test('asks for mail and identity, and nothing else', () {
      final List<String> scopes = url.queryParameters['scope']!.split(' ');
      expect(scopes, contains('https://mail.google.com/'));
      expect(scopes, containsAll(<String>['openid', 'email', 'profile']));
      expect(scopes.length, 4);
    });
  });

  group('ID token claims', () {
    test('the email and name come out of the payload', () {
      final String token = _idToken(<String, Object?>{
        'email': 'someone@example.com',
        'name': 'Some One',
      });
      expect(GoogleDesktopAuth.emailFromIdToken(token), 'someone@example.com');
      expect(GoogleDesktopAuth.nameFromIdToken(token), 'Some One');
    });

    test('a token without an email gives none, rather than an empty one', () {
      final String token = _idToken(<String, Object?>{'sub': '123'});
      expect(GoogleDesktopAuth.emailFromIdToken(token), isNull);
    });

    test('a blank email is treated as no email', () {
      final String token = _idToken(<String, Object?>{'email': '   '});
      expect(GoogleDesktopAuth.emailFromIdToken(token), isNull);
    });

    test('something that is not a token is refused quietly', () {
      expect(GoogleDesktopAuth.emailFromIdToken('not-a-token'), isNull);
      expect(GoogleDesktopAuth.emailFromIdToken('a.!!!.c'), isNull);
    });
  });

  group('configuration', () {
    test('without a desktop client, sign-in says so instead of opening a browser',
        () async {
      // The tests run without --dart-define, so no client is configured.
      expect(GoogleDesktopAuth.configured, isFalse);
      expect(
        GoogleDesktopAuth.signIn(),
        throwsA(isA<GoogleAuthException>()),
      );
    });
  });
}
