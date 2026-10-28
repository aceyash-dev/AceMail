import 'dart:convert';

import 'package:ace_mail/services/ace_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// A JWT-shaped string with [claims] as its payload. Unsigned on purpose: the
/// app reads claims and never verifies them, and a test that signed one would
/// be testing a verifier this code does not have.
String idToken(Map<String, Object?> claims) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part(<String, String>{'alg': 'RS256'})}.${part(claims)}.signature';
}

void main() {
  group('the tenant is read from the build', () {
    test('an unconfigured build says so instead of pretending', () {
      // The test build has no --dart-define, which is the state a developer
      // cloning the repository is in.
      expect(AceAuth.configured, isFalse);
      expect(AceAuth.domain, isEmpty);
      expect(AceAuth.clientId, isEmpty);
    });

    test('Google is the default connection', () {
      // The one connection that can hand back a mailbox token. A tenant may
      // point it elsewhere, but the default is the one that works.
      expect(AceAuth.connection, 'google-oauth2');
    });

    test('a refresh token is asked for, or nothing renews', () {
      expect(AceAuth.scopes, contains('offline_access'));
      expect(AceAuth.scopes, contains('openid'));
    });
  });

  group('the authorisation URL', () {
    Uri url() => AceAuth.authorisationUrl(
          redirectUri: 'http://127.0.0.1:5000/callback',
          state: 'state-123',
          codeChallenge: 'challenge-abc',
        );

    test('is a code flow with PKCE, which is what a native client needs', () {
      final Map<String, String> q = url().queryParameters;
      expect(q['response_type'], 'code');
      expect(q['code_challenge'], 'challenge-abc');
      expect(q['code_challenge_method'], 'S256');
      expect(q['state'], 'state-123');
    });

    test('names the connection and asks Google for a refresh token', () {
      final Map<String, String> q = url().queryParameters;
      expect(q['connection'], 'google-oauth2');
      expect(q['access_type'], 'offline');
      expect(q['prompt'], 'consent');
    });

    test('carries the redirect it will answer on', () {
      expect(
        url().queryParameters['redirect_uri'],
        'http://127.0.0.1:5000/callback',
      );
    });

    test('an audience is sent only when the tenant has one', () {
      expect(url().queryParameters.containsKey('audience'), isFalse);
    });
  });

  group('the identity in an ID token', () {
    test('the address comes out of the payload', () {
      expect(
        AceAuth.emailFromIdToken(idToken(<String, Object?>{
          'email': 'someone@example.com',
          'name': 'Some One',
        })),
        'someone@example.com',
      );
    });

    test('the name comes out too, and is null when there is none', () {
      expect(
        AceAuth.nameFromIdToken(idToken(<String, Object?>{'name': 'Some One'})),
        'Some One',
      );
      expect(
        AceAuth.nameFromIdToken(idToken(<String, Object?>{'email': 'a@b.c'})),
        isNull,
      );
    });

    test('anything that is not a token is null rather than a crash', () {
      expect(AceAuth.emailFromIdToken(null), isNull);
      expect(AceAuth.emailFromIdToken(''), isNull);
      expect(AceAuth.emailFromIdToken('not-a-token'), isNull);
      expect(AceAuth.emailFromIdToken('a.b'), isNull);
      expect(AceAuth.emailFromIdToken('a.!!!.c'), isNull);
    });

    test('an empty claim is not an address', () {
      expect(
        AceAuth.emailFromIdToken(idToken(<String, Object?>{'email': ''})),
        isNull,
      );
    });
  });

  group('nothing is minted without a tenant', () {
    test('no token, and no exception, on an unconfigured build', () async {
      // Null is the documented answer for "this build cannot mint one": the
      // caller says so on screen. Throwing here would turn a missing
      // --dart-define into a mailbox that will not open.
      expect(await AceAuth.token('someone@example.com'), isNull);
    });
  });
}
