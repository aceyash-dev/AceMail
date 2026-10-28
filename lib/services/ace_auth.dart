import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../util/redact.dart';

/// Signing in did not finish.
class AceAuthException implements Exception {
  const AceAuthException(this.message, {this.needsSignIn = false});

  final String message;

  /// True when the answer is "sign in again" rather than "something is broken".
  final bool needsSignIn;

  @override
  String toString() => message;
}

/// An account, and the mailbox token for it.
typedef AceCredential = ({String email, String token, String? name});

/// Sign-in, through Auth0.
///
/// Gmail stopped accepting app passwords in 2022; IMAP and SMTP authenticate it
/// with an OAuth access token by SASL XOAUTH2 instead. The token has to be
/// Google's — a Google access token for `https://mail.google.com/` — and where
/// it comes from is a decision about the app rather than about mail.
///
/// It came straight from Google before: a Cloud project, a web client ID, the
/// `google_sign_in` plugin on mobile and a hand-written PKCE loop on desktop.
/// Two implementations, two configurations, and the mobile one could not even
/// ask for the mail scope in the same breath as the identity — the button flow
/// rejects a restricted scope, so the consent came in two pieces and the second
/// one was where people stopped.
///
/// Now it comes from **Auth0**: one OAuth client, one redirect, one consent
/// screen that carries Google's inside it, and the same code on every platform.
/// Auth0 holds the Google client secret and the verification; this app holds a
/// client ID and a refresh token.
///
/// **What this app stores.** The Auth0 refresh token, in the platform keychain,
/// per address. Not a password, not a Google token: the Google token is minted
/// on demand by exchanging the Auth0 session for it, and lives in memory for the
/// length of a connection. Revoking the app in Auth0 ends its access; nothing on
/// the device can be replayed afterwards.
///
/// **What the tenant must be.** A Native (or Regular Web) application with
/// `http://127.0.0.1:*/callback` allowed, a `google-oauth2` social connection
/// with the `https://mail.google.com/` scope, and provider access tokens turned
/// on for it — see the README. Without the last one the exchange below answers
/// with an Auth0 token instead of Google's, and Gmail rejects it, which is why
/// the failure says so by name.
abstract final class AceAuth {
  /// The tenant, as `something.eu.auth0.com`.
  static const String domain = String.fromEnvironment('AUTH0_DOMAIN');

  /// The application's client ID.
  static const String clientId = String.fromEnvironment('AUTH0_CLIENT_ID');

  /// Its secret, for a Regular Web application. A native client with PKCE does
  /// not need one, and most builds will not have it.
  static const String clientSecret =
      String.fromEnvironment('AUTH0_CLIENT_SECRET');

  /// Which connection to use. Google is the one that can give a mailbox token.
  static const String connection =
      String.fromEnvironment('AUTH0_CONNECTION', defaultValue: 'google-oauth2');

  /// The API audience, when the tenant defines one.
  static const String audience = String.fromEnvironment('AUTH0_AUDIENCE');

  /// Whether this build was given a tenant at all.
  ///
  /// False is not a crash: the sign-in screen says the build has no auth
  /// configured and offers a password, which still works for every provider
  /// that is not Gmail.
  static bool get configured => domain.isNotEmpty && clientId.isNotEmpty;

  /// OpenID identity, plus a refresh token so the app can renew without asking.
  static const List<String> scopes = <String>[
    'openid',
    'profile',
    'email',
    'offline_access',
  ];

  /// How long somebody has to finish in the browser.
  static const Duration browserTimeout = Duration(minutes: 5);

  /// Renew this long before the token actually expires.
  static const Duration renewalMargin = Duration(minutes: 5);

  static const String _keyEmail = 'ace.auth.email';
  static const String _keyName = 'ace.auth.name';
  static const String _keyRefresh = 'ace.auth.refresh';
  static const String _keyExpiry = 'ace.auth.expiry';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<String?> _read(String key) async {
    try {
      final String? value = await _storage.read(key: key);
      return (value == null || value.isEmpty) ? null : value;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // A keychain that will not take it costs a sign-in, not the app.
    }
  }

  static Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {
      // Already gone is the state being asked for.
    }
  }

  // --- the flow -----------------------------------------------------------

  /// The consent screen's URL. Pure, so it can be tested without a tenant.
  static Uri authorisationUrl({
    required String redirectUri,
    required String state,
    required String codeChallenge,
    String? hint,
  }) {
    return Uri.https(domain, '/authorize', <String, String>{
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': scopes.join(' '),
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      // Which identity provider to go through, and the parameters Google needs
      // to hand back a refresh token of its own.
      'connection': connection,
      'access_type': 'offline',
      'prompt': 'consent',
      if (audience.isNotEmpty) 'audience': audience,
      if (hint != null && hint.isNotEmpty) 'login_hint': hint,
    });
  }

  /// Opens the consent screen and waits for the answer.
  ///
  /// A loopback redirect (RFC 8252), which is what Auth0 documents for a native
  /// app and what makes this the same code on every platform: a socket on
  /// 127.0.0.1 answers once and closes. There is no custom scheme to register
  /// with the operating system, and no plugin to keep in step.
  static Future<AceCredential> signIn({String? hint}) async {
    if (!configured) {
      throw const AceAuthException(
        'This build has no Auth0 tenant configured. Set AUTH0_DOMAIN and '
        'AUTH0_CLIENT_ID at build time.',
      );
    }

    final String verifier = _randomString(64);
    final String state = _randomString(24);
    final String challenge = _challengeFor(verifier);

    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final String redirect = 'http://127.0.0.1:${server.port}/callback';

    try {
      final Uri url = authorisationUrl(
        redirectUri: redirect,
        state: state,
        codeChallenge: challenge,
        hint: hint,
      );
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw const AceAuthException('Could not open the sign-in page.');
      }

      final String code = await _waitForCode(server, state);
      final Map<String, Object?> tokens = await _post(<String, String>{
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'code': code,
        'redirect_uri': redirect,
        'code_verifier': verifier,
        if (clientSecret.isNotEmpty) 'client_secret': clientSecret,
      });

      final String access = (tokens['access_token'] as String?) ?? '';
      final String? refresh = tokens['refresh_token'] as String?;
      final String? idToken = tokens['id_token'] as String?;
      if (access.isEmpty) {
        throw const AceAuthException('Auth0 did not return a token.');
      }

      final String email = emailFromIdToken(idToken) ?? '';
      if (email.isEmpty) {
        throw const AceAuthException(
          'Auth0 did not say which account signed in.',
        );
      }
      final String? name = nameFromIdToken(idToken);

      // The mailbox token: Google's, minted from this Auth0 session.
      final String mailbox = await _providerToken(access);

      final String suffix = '.${email.toLowerCase()}';
      if (refresh != null && refresh.isNotEmpty) {
        await _write('$_keyRefresh$suffix', refresh);
      }
      await _write(_keyEmail, email);
      if (name != null && name.isNotEmpty) await _write(_keyName, name);
      await _write(
        '$_keyExpiry$suffix',
        DateTime.now().add(_lifetime(tokens)).toIso8601String(),
      );

      return (email: email, token: mailbox, name: name);
    } on AceAuthException {
      rethrow;
    } catch (error) {
      throw AceAuthException('Sign-in failed. ${Redact.safe(error)}');
    } finally {
      // The socket closes either way: a redirect nobody is waiting for is a
      // port held open on somebody's phone.
      unawaited(server.close(force: true));
    }
  }

  /// A mailbox token for [email], without asking anybody.
  ///
  /// The reconnect path: a token lives an hour, so a connection opened later
  /// needs a new one, and this is where it comes from. Every route here is
  /// silent — a stored refresh token, or nothing. Null means the app needs a
  /// sign-in it cannot perform by itself, and the caller says so.
  static Future<String?> token([String? email]) async {
    if (!configured) return null;
    final String? want = email?.trim().toLowerCase();
    final String? storedEmail = await _read(_keyEmail);
    final String suffix = '.${(want ?? storedEmail ?? '').toLowerCase()}';
    if (suffix == '.') return null;

    final String? refresh = await _read('$_keyRefresh$suffix');
    if (refresh == null) return null;

    try {
      final Map<String, Object?> renewed = await _post(<String, String>{
        'grant_type': 'refresh_token',
        'client_id': clientId,
        'refresh_token': refresh,
        if (clientSecret.isNotEmpty) 'client_secret': clientSecret,
      });
      final String access = (renewed['access_token'] as String?) ?? '';
      if (access.isEmpty) return null;
      final String? rotated = renewed['refresh_token'] as String?;
      if (rotated != null && rotated.isNotEmpty) {
        // Refresh-token rotation: keeping the old one would end the session at
        // the next renewal, which is a sign-in nobody scheduled.
        await _write('$_keyRefresh$suffix', rotated);
      }
      await _write(
        '$_keyExpiry$suffix',
        DateTime.now().add(_lifetime(renewed)).toIso8601String(),
      );
      return await _providerToken(access);
    } on AceAuthException {
      return null;
    }
  }

  /// The account this device signed in as, if any.
  static Future<String?> knownEmail() => _read(_keyEmail);

  /// The name to greet them by.
  static Future<String?> knownName() => _read(_keyName);

  /// Signs out: the next connection asks for an account again.
  static Future<void> forget() async {
    final String? email = await _read(_keyEmail);
    if (email != null && email.isNotEmpty) {
      final String suffix = '.${email.toLowerCase()}';
      await _delete('$_keyRefresh$suffix');
      await _delete('$_keyExpiry$suffix');
    }
    await _delete(_keyEmail);
    await _delete(_keyName);
  }

  // --- the pieces ---------------------------------------------------------

  /// Exchanges the Auth0 session for Google's own access token.
  ///
  /// This is the step that makes the whole arrangement work, and the one that
  /// fails if the tenant is not set up for it: Auth0 will only hand back a
  /// provider token when the connection is configured to keep one. Gmail then
  /// rejects an Auth0 token with a message about credentials, which reads like a
  /// wrong password and is not.
  static Future<String> _providerToken(String auth0AccessToken) async {
    final Map<String, Object?> answer = await _post(<String, String>{
      'grant_type': 'urn:ietf:params:oauth:grant-type:token-exchange',
      'client_id': clientId,
      'subject_token': auth0AccessToken,
      'subject_token_type': 'urn:auth0:params:oauth:token-type:access_token',
      'requested_token_type': 'urn:auth0:params:oauth:token-type:idp_token',
      'audience': 'urn:auth0:$connection',
      if (clientSecret.isNotEmpty) 'client_secret': clientSecret,
    });

    final String token = (answer['access_token'] as String?) ?? '';
    if (token.isEmpty) {
      throw const AceAuthException(
        'Auth0 did not return a mailbox token. The Google connection needs '
        'provider access tokens turned on for it.',
        needsSignIn: true,
      );
    }
    return token;
  }

  /// Waits for the redirect, and answers it with something readable.
  static Future<String> _waitForCode(HttpServer server, String state) async {
    final Completer<String> done = Completer<String>();
    late final StreamSubscription<HttpRequest> subscription;
    final Timer timer = Timer(browserTimeout, () {
      if (!done.isCompleted) {
        done.completeError(
          const AceAuthException('Sign-in timed out. Try again.'),
        );
      }
    });

    subscription = server.listen((HttpRequest request) async {
      final Map<String, String> query = request.uri.queryParameters;
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(_closingPage);
      unawaited(request.response.close());

      if (done.isCompleted) return;
      if (query['state'] != state) {
        done.completeError(
          const AceAuthException('Sign-in was interrupted. Try again.'),
        );
        return;
      }
      final String? error = query['error'];
      if (error != null) {
        final String description = query['error_description'] ?? error;
        done.completeError(
          AceAuthException(
            error == 'access_denied'
                ? 'Sign-in was cancelled.'
                : 'Auth0 said: $description',
          ),
        );
        return;
      }
      final String? code = query['code'];
      if (code == null || code.isEmpty) {
        done.completeError(
          const AceAuthException('Auth0 returned no code.'),
        );
        return;
      }
      done.complete(code);
    });

    try {
      return await done.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }

  /// POSTs to the token endpoint, as form data, and returns the JSON.
  static Future<Map<String, Object?>> _post(Map<String, String> body) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.postUrl(
        Uri.https(domain, '/oauth/token'),
      );
      request.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded');
      request.write(Uri(queryParameters: body).query);
      final HttpClientResponse response = await request.close();
      final String text = await response.transform(utf8.decoder).join();
      final Object? decoded = text.isEmpty ? null : jsonDecode(text);
      if (response.statusCode >= 400) {
        final String said = decoded is Map<String, Object?>
            ? '${decoded['error']}: ${decoded['error_description'] ?? ''}'
            : 'HTTP ${response.statusCode}';
        throw AceAuthException(
          'Auth0 refused the request ($said).',
          needsSignIn: response.statusCode == 401 || response.statusCode == 403,
        );
      }
      return decoded is Map<String, Object?> ? decoded : <String, Object?>{};
    } finally {
      client.close(force: true);
    }
  }

  static Duration _lifetime(Map<String, Object?> tokens) {
    final Object? seconds = tokens['expires_in'];
    final int value = seconds is int
        ? seconds
        : int.tryParse('${seconds ?? ''}') ?? 3600;
    final Duration life = Duration(seconds: value) - renewalMargin;
    return life.isNegative ? const Duration(minutes: 1) : life;
  }

  /// The address in an ID token.
  ///
  /// Read, not verified: the token arrived over TLS from the tenant this build
  /// is pinned to, on a connection this app opened, and it is used to label an
  /// account — never to authorise anything. The mailbox token is the thing that
  /// authorises, and it comes from the exchange above.
  static String? emailFromIdToken(String? idToken) =>
      _claim(idToken, 'email');

  /// The name in an ID token.
  static String? nameFromIdToken(String? idToken) => _claim(idToken, 'name');

  static String? _claim(String? idToken, String claim) {
    if (idToken == null || idToken.isEmpty) return null;
    final List<String> parts = idToken.split('.');
    if (parts.length < 2) return null;
    try {
      final String payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final Object? decoded = jsonDecode(payload);
      if (decoded is! Map<String, Object?>) return null;
      final Object? value = decoded[claim];
      return value is String && value.isNotEmpty ? value : null;
    } catch (_) {
      return null;
    }
  }

  static String _randomString(int length) {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String _challengeFor(String verifier) =>
      base64Url.encode(sha256.convert(utf8.encode(verifier)).bytes)
          .replaceAll('=', '');

  /// The page the browser lands on. It is the last thing anybody sees of the
  /// flow, so it says what happened rather than showing a blank tab.
  static const String _closingPage = '''
<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Ace Mail</title></head>
<body style="font-family:system-ui,sans-serif;padding:2rem;text-align:center">
<p style="font-size:1.1rem">Signed in. You can close this tab.</p>
</body></html>
''';
}
