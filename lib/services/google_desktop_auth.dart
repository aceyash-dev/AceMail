import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../util/redact.dart';
import 'google_auth.dart' show GoogleAuthException, GoogleCredential;

/// Google sign-in for desktop builds, where the mobile plugin does not run.
///
/// `google_sign_in` covers Android, iOS, macOS and the web. Linux and Windows
/// have no implementation, so there the app opens the system browser instead
/// and receives the answer on a loopback address, which is the flow Google
/// documents for installed apps (RFC 8252): PKCE, a random `state`, and a
/// redirect to `http://127.0.0.1:<port>`.
///
/// Two things differ from the mobile path, and both are deliberate:
///
/// * **A refresh token is kept.** A desktop app cannot fetch a fresh token
///   silently the way the mobile plugin does, so without one the person would
///   be sent to the browser every hour. The refresh token is stored in the
///   platform keychain (libsecret on Linux), the same place every password
///   for the other providers already lives. It is never written to a plain file.
/// * **The build must carry a Desktop OAuth client.** Google issues desktop
///   clients their own ID and secret, separate from the mobile ones. They are
///   passed at build time with `--dart-define`, so no secret is in the source.
abstract final class GoogleDesktopAuth {
  /// The desktop OAuth client, from the build.
  static const String clientId =
      String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');

  /// Its secret. Google requires it at the token endpoint even with PKCE for
  /// desktop clients; it is not treated as confidential for installed apps.
  static const String clientSecret =
      String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET');

  /// Whether this build was given a desktop client at all.
  static bool get configured => clientId.isNotEmpty && clientSecret.isNotEmpty;

  /// IMAP and SMTP, plus the identity needed to name the account.
  static const List<String> scopes = <String>[
    'https://mail.google.com/',
    'openid',
    'email',
    'profile',
  ];

  static const String _authEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const String _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const String _revokeEndpoint = 'https://oauth2.googleapis.com/revoke';

  /// How long the person has to finish in the browser before the attempt ends.
  static const Duration browserTimeout = Duration(minutes: 5);

  /// Renew this long before the access token actually expires, so a request
  /// does not start with a token that dies on the way.
  static const Duration _renewMargin = Duration(minutes: 1);

  static const String _keyRefresh = 'ace.google.desktop.refresh';
  static const String _keyEmail = 'ace.google.desktop.email';
  static const String _keyName = 'ace.google.desktop.name';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String? _accessToken;
  static DateTime _accessExpiresAt = DateTime.fromMillisecondsSinceEpoch(0);

  // ---------------------------------------------------------------------------
  // Public surface, shaped like the mobile one in GoogleAuth.
  // ---------------------------------------------------------------------------

  /// The account already signed in on this device, without opening anything.
  static Future<String?> knownEmail() => _read(_keyEmail);

  /// The name Google has for that account, if it gave one.
  static Future<String?> knownName() => _read(_keyName);

  /// Opens the browser, and returns the account and a token once it is done.
  static Future<GoogleCredential> signIn() async {
    if (!configured) {
      throw const GoogleAuthException(
        'This build has no desktop Google client. It needs '
        'GOOGLE_DESKTOP_CLIENT_ID and GOOGLE_DESKTOP_CLIENT_SECRET at build time.',
      );
    }

    final _Grant grant = await _authorise();
    final String? refresh = grant.tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      // Google only gives a refresh token when asked for consent. Without one
      // the app would be back in the browser within the hour, so refuse now
      // with an explanation rather than sign in to something that will not last.
      throw const GoogleAuthException(
        'Google did not give Ace Mail a lasting sign-in. Remove Ace Mail from '
        'your Google account permissions and try again.',
      );
    }

    final String email = grant.email ?? '';
    if (email.isEmpty) {
      throw const GoogleAuthException('Google did not say which account this is.');
    }

    await _write(_keyRefresh, refresh);
    await _write(_keyEmail, email);
    await _write(_keyName, grant.name ?? '');
    _remember(grant.tokens.accessToken, grant.tokens.expiresIn);

    return (email: email, token: grant.tokens.accessToken, name: grant.name);
  }

  /// A token for the stored account, renewed when it is close to expiry.
  ///
  /// Null means nobody has signed in. Throws with `needsSignIn` when Google has
  /// withdrawn the grant, so the screen can ask again instead of showing an
  /// error nobody can act on.
  static Future<String?> token() async {
    final String? cached = _accessToken;
    if (cached != null && DateTime.now().isBefore(_accessExpiresAt.subtract(_renewMargin))) {
      return cached;
    }

    final String? refresh = await _read(_keyRefresh);
    if (refresh == null || refresh.isEmpty) return null;

    final _Tokens renewed = await _refresh(refresh);
    _remember(renewed.accessToken, renewed.expiresIn);
    return renewed.accessToken;
  }

  /// Signs out: forgets the stored grant and asks Google to revoke it. The
  /// revoke is best effort — the local copy is gone either way.
  static Future<void> forget() async {
    final String? refresh = await _read(_keyRefresh);
    _accessToken = null;
    _accessExpiresAt = DateTime.fromMillisecondsSinceEpoch(0);
    for (final String key in <String>[_keyRefresh, _keyEmail, _keyName]) {
      try {
        await _storage.delete(key: key);
      } catch (error) {
        debugPrint('Ace Mail: could not clear $key (${Redact.safe(error)})');
      }
    }
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _postForm(_revokeEndpoint, <String, String>{'token': refresh});
      } catch (error) {
        debugPrint('Ace Mail: could not revoke the grant (${Redact.safe(error)})');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Pure pieces, separated so the tests can reach them without a browser.
  // ---------------------------------------------------------------------------

  /// The address the person is sent to. Pure: no network, no state.
  static Uri authorisationUrl({
    required String redirectUri,
    required String state,
    required String codeChallenge,
    String clientId = GoogleDesktopAuth.clientId,
  }) {
    return Uri.parse(_authEndpoint).replace(
      queryParameters: <String, String>{
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': scopes.join(' '),
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        // A refresh token is only issued with offline access and consent.
        'access_type': 'offline',
        'prompt': 'consent',
        'include_granted_scopes': 'true',
      },
    );
  }

  /// The email from an ID token's payload. The token came straight from
  /// Google over TLS in answer to our own request, so its claims are read but
  /// not verified against Google's keys — there is nothing to verify it against
  /// that the request itself did not already establish.
  static String? emailFromIdToken(String idToken) =>
      _stringClaim(idToken, 'email');

  /// The display name in an ID token's payload, if it has one.
  static String? nameFromIdToken(String idToken) =>
      _stringClaim(idToken, 'name');

  static String? _stringClaim(String idToken, String claim) {
    final List<String> parts = idToken.split('.');
    if (parts.length != 3) return null;
    try {
      final Object? claims = jsonDecode(utf8.decode(_decodeSegment(parts[1])));
      if (claims is! Map<String, dynamic>) return null;
      final Object? value = claims[claim];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    } on FormatException {
      return null;
    }
  }

  /// A JWT segment is base64url without its padding, which `base64Url.decode`
  /// needs put back.
  static List<int> _decodeSegment(String segment) {
    final StringBuffer padded = StringBuffer(segment);
    while (padded.length % 4 != 0) {
      padded.write('=');
    }
    return base64Url.decode(padded.toString());
  }

  // ---------------------------------------------------------------------------
  // The browser round trip.
  // ---------------------------------------------------------------------------

  static Future<_Grant> _authorise() async {
    final PkcePair pkce = PkceFactory.create();
    final String state = _randomUrlSafe(24);

    // Port zero: the system picks a free one, so nothing else on the machine
    // has to be running on a known port. The redirect is loopback only.
    final HttpServer server =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final String redirectUri = 'http://127.0.0.1:${server.port}/';
    final Completer<String> answer = Completer<String>();
    // A browser that reports an error can finish the answer before anyone is
    // waiting on it. Marking the future handled keeps that from being reported
    // as an uncaught error; the wait below still receives the outcome.
    unawaited(answer.future.then<void>((_) {}, onError: (Object _) {}));

    final StreamSubscription<HttpRequest> subscription = server.listen(
      (HttpRequest request) => _answerBrowser(request, state, answer),
    );

    try {
      final Uri url = authorisationUrl(
        redirectUri: redirectUri,
        state: state,
        codeChallenge: pkce.challenge,
      );
      final bool opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw const GoogleAuthException(
          'Could not open the browser for Google sign-in.',
        );
      }

      final String code = await _waitForCode(answer);

      final _Tokens tokens = await _exchange(
        code: code,
        verifier: pkce.verifier,
        redirectUri: redirectUri,
      );
      final String? idToken = tokens.idToken;
      return _Grant(
        tokens: tokens,
        email: idToken == null ? null : emailFromIdToken(idToken),
        name: idToken == null ? null : nameFromIdToken(idToken),
      );
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  }

  static Future<String> _waitForCode(Completer<String> answer) async {
    try {
      return await answer.future.timeout(browserTimeout);
    } on TimeoutException {
      throw const GoogleAuthException('Google sign-in timed out. Try again.');
    }
  }

  /// Answers the browser's redirect. Only the first answer counts; anything
  /// without the right `state` is refused, so another page on the machine
  /// cannot inject a code into the flow.
  static Future<void> _answerBrowser(
    HttpRequest request,
    String expectedState,
    Completer<String> answer,
  ) async {
    final Map<String, String> query = request.uri.queryParameters;
    final HttpResponse response = request.response;
    response.headers.contentType = ContentType.html;

    if (query['state'] != expectedState) {
      response.statusCode = HttpStatus.badRequest;
      response.write(_page('This sign-in was not started by Ace Mail.'));
      await response.close();
      return;
    }

    final String? error = query['error'];
    if (error != null) {
      if (!answer.isCompleted) {
        answer.completeError(
          const GoogleAuthException('Sign-in was cancelled.'),
        );
      }
      response.write(_page('Sign-in was not completed. You can close this tab.'));
      await response.close();
      return;
    }

    final String? code = query['code'];
    if (code == null || code.isEmpty) {
      response.statusCode = HttpStatus.badRequest;
      response.write(_page('Google sent no sign-in code. Try again from Ace Mail.'));
      await response.close();
      return;
    }

    if (!answer.isCompleted) answer.complete(code);
    response.write(_page('Signed in to Ace Mail. You can close this tab.'));
    await response.close();
  }

  static String _page(String message) =>
      '<!doctype html><meta charset="utf-8"><title>Ace Mail</title>'
      '<body style="font-family:sans-serif;padding:2em">'
      '<p>${const HtmlEscape().convert(message)}</p></body>';

  // ---------------------------------------------------------------------------
  // The token endpoint.
  // ---------------------------------------------------------------------------

  static Future<_Tokens> _exchange({
    required String code,
    required String verifier,
    required String redirectUri,
  }) async {
    final Map<String, Object?> body = await _postForm(_tokenEndpoint, <String, String>{
      'grant_type': 'authorization_code',
      'code': code,
      'code_verifier': verifier,
      'redirect_uri': redirectUri,
      'client_id': clientId,
      'client_secret': clientSecret,
    });
    return _Tokens.fromJson(body);
  }

  static Future<_Tokens> _refresh(String refreshToken) async {
    final Map<String, Object?> body = await _postForm(_tokenEndpoint, <String, String>{
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': clientId,
      'client_secret': clientSecret,
    });
    return _Tokens.fromJson(body);
  }

  /// One form POST. A rejected grant comes back as `needsSignIn`; anything
  /// else as a plain failure with what Google said, minus anything secret.
  static Future<Map<String, Object?>> _postForm(
    String endpoint,
    Map<String, String> form,
  ) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final HttpClientRequest request = await client.postUrl(Uri.parse(endpoint));
      request.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      request.write(Uri(queryParameters: form).query);
      final HttpClientResponse response = await request.close();
      final String text = await utf8.decodeStream(response);

      // The type matters: `_decodeObject` returns a map or null, and widening
      // it to `Object?` here is what made the return and the lookup below fail
      // to compile.
      final Map<String, Object?>? decoded = _decodeObject(text);
      if (decoded == null) {
        throw const GoogleAuthException('Google sent an answer Ace Mail could not read.');
      }

      if (response.statusCode == HttpStatus.ok) return decoded;

      final String? reason = decoded['error'] as String?;
      if (reason == 'invalid_grant' || reason == 'unauthorized_client') {
        throw const GoogleAuthException(
          'Google needs you to sign in again.',
          needsSignIn: true,
        );
      }
      throw GoogleAuthException(
        'Google sign-in failed (${response.statusCode}${reason == null ? '' : ': $reason'}).',
      );
    } on SocketException {
      throw const GoogleAuthException('Could not reach Google. Check the connection.');
    } on HandshakeException {
      throw const GoogleAuthException('Could not reach Google securely.');
    } finally {
      client.close(force: true);
    }
  }

  static Map<String, Object?>? _decodeObject(String text) {
    try {
      final Object? value = jsonDecode(text);
      if (value is Map<String, dynamic>) return value.cast<String, Object?>();
      return null;
    } on FormatException {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Small helpers.
  // ---------------------------------------------------------------------------

  static void _remember(String token, int expiresIn) {
    _accessToken = token;
    _accessExpiresAt = DateTime.now().add(Duration(seconds: expiresIn));
  }

  static Future<String?> _read(String key) async {
    try {
      final String? value = await _storage.read(key: key);
      return (value == null || value.isEmpty) ? null : value;
    } catch (error) {
      // No keychain (a headless Linux session, say) is "nobody signed in",
      // not a crash on the first frame of the app.
      debugPrint('Ace Mail: could not read $key (${Redact.safe(error)})');
      return null;
    }
  }

  static Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (error) {
      throw const GoogleAuthException(
        'Could not keep the sign-in on this device. Is the keychain available?',
      );
    }
  }

  static String _randomUrlSafe(int bytes) {
    final Random random = Random.secure();
    final List<int> raw =
        List<int>.generate(bytes, (_) => random.nextInt(256));
    return base64UrlEncode(raw).replaceAll('=', '');
  }
}

/// A PKCE pair (RFC 7636): the secret verifier, and its S256 challenge.
class PkcePair {
  const PkcePair(this.verifier, this.challenge);

  final String verifier;
  final String challenge;
}

/// The one place a PKCE pair is made. Thirty-two random bytes encode to a
/// 43-character verifier, the shortest the RFC allows to be safe.
abstract final class PkceFactory {
  static PkcePair create([Random? random]) {
    final Random source = random ?? Random.secure();
    final List<int> raw = List<int>.generate(32, (_) => source.nextInt(256));
    final String verifier = base64UrlEncode(raw).replaceAll('=', '');
    final String challenge = base64UrlEncode(
      sha256.convert(utf8.encode(verifier)).bytes,
    ).replaceAll('=', '');
    return PkcePair(verifier, challenge);
  }
}

/// The access token and what came with it.
class _Tokens {
  const _Tokens({
    required this.accessToken,
    required this.expiresIn,
    this.refreshToken,
    this.idToken,
  });

  factory _Tokens.fromJson(Map<String, Object?> json) {
    final Object? access = json['access_token'];
    if (access is! String || access.isEmpty) {
      throw const GoogleAuthException('Google did not send an access token.');
    }
    final Object? expires = json['expires_in'];
    return _Tokens(
      accessToken: access,
      expiresIn: expires is int ? expires : 3600,
      refreshToken: json['refresh_token'] as String?,
      idToken: json['id_token'] as String?,
    );
  }

  final String accessToken;
  final int expiresIn;
  final String? refreshToken;
  final String? idToken;
}

class _Grant {
  const _Grant({required this.tokens, required this.email, required this.name});

  final _Tokens tokens;
  final String? email;
  final String? name;
}
