import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_desktop_auth.dart';

/// Google sign-in could not be completed.
class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message, {this.needsSignIn = false});

  final String message;

  /// True when the answer is "sign in again" rather than "something is broken"
  /// — a revoked grant, or an account that was never authorised for this scope.
  final bool needsSignIn;

  @override
  String toString() => message;
}

/// A Google account and a token for it.
typedef GoogleCredential = ({String email, String token, String? name});

/// Signing in with Google.
///
/// Gmail still speaks IMAP and SMTP, but it stopped accepting app passwords in
/// 2022. The protocols are authenticated with an OAuth access token instead, by
/// SASL XOAUTH2 — which is the whole reason this exists: without it, Gmail is a
/// provider this app cannot offer at all.
///
/// What the app gets out of it, beyond the token:
///
/// * **Nothing is stored.** There is no password and no refresh token on the
///   device. The token lives about an hour, and a new one is fetched when a
///   connection needs it. An account whose credentials cannot leak because
///   there are none is the strongest version of the promise the keychain was
///   making.
/// * **The consent is Google's screen, not ours.** The app never sees the
///   password, and the grant can be revoked from the account page.
///
/// The scope is the full-access one because that is what XOAUTH2 needs: Google
/// offers no narrower grant that lets a client read *and* send mail over IMAP
/// and SMTP. It is a restricted scope, so the consent screen has to list it and
/// the account has to be a test user until the app is verified.
abstract final class GoogleAuth {
  /// The OAuth client this build is registered under.
  ///
  /// It is the **web** client ID, which is what Android's Credential Manager
  /// wants as `serverClientId` when the app is not configured through a
  /// `google-services.json`. The Android client that matches this app is
  /// registered against the package name and the signing certificate instead —
  /// see the README.
  static const String clientId =
      '919591212641-7m696qr165fh1ir4uo6d761jn7nnk4kg.apps.googleusercontent.com';

  /// IMAP and SMTP, read and send.
  static const List<String> scopes = <String>['https://mail.google.com/'];

  static Future<void>? _prepareFuture;

  /// Linux and Windows have no `google_sign_in` implementation, so there the
  /// sign-in happens in the browser instead. Same answers, different road.
  static bool get _desktop =>
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.windows;

  /// Prepares the plugin. Once, before anything else touches it.
  static Future<void> _prepare() => _prepareFuture ??= _initialize();

  static Future<void> _initialize() async {
    try {
      await GoogleSignIn.instance.initialize(serverClientId: clientId);
    } catch (_) {
      // A failed initialization is not a successful one. Clear the cached
      // future so a transient platform failure does not poison every retry.
      _prepareFuture = null;
      rethrow;
    }
  }

  /// Where the signed-in account's address and name are kept.
  ///
  /// The desktop path has always cached these; the mobile path asked the plugin
  /// every time, and that call can **prompt**. `attemptLightweightAuthentication`
  /// is documented as minimal-interaction, but its implementation falls through
  /// to a second attempt with `autoSelectEnabled: false` when nothing can be
  /// auto-selected — which shows the Credential Manager picker. So a lookup that
  /// is supposed to be silent could put a sheet on screen when the app opened,
  /// before anybody had touched anything.
  ///
  /// A cached answer cannot prompt, and it is the only answer needed: the
  /// greeting wants the name of the account that is signed in, and if none is,
  /// there is no name to want.
  static const String _keyEmail = 'ace.google.email';
  static const String _keyName = 'ace.google.name';
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
      // A keychain that will not take it costs a greeting, not a sign-in.
    }
  }

  /// The account already signed in to this device, without showing anything.
  ///
  /// Read from the cache, never from the plugin: see [_keyEmail]. Null is the
  /// ordinary answer — nobody has signed in yet, or the last grant was
  /// withdrawn — and it is a fine one, because a name is only knowable for an
  /// account that is actually signed in.
  static Future<String?> knownEmail() async {
    if (_desktop) return GoogleDesktopAuth.knownEmail();
    return _read(_keyEmail);
  }

  /// The name Google has for the signed-in account, if there is one.
  ///
  /// Free — it comes back with the lightweight sign-in — and it is the only
  /// provider here that can say what to call somebody without being asked.
  static Future<String?> knownName() async {
    if (_desktop) return GoogleDesktopAuth.knownName();
    return _read(_keyName);
  }

  /// Asks the user to choose an account and consent, and returns a token.
  ///
  /// **This is the sheet people recognise**: Credential Manager's bottom sheet
  /// with "Sign in with Google" on it. Underneath it is
  /// `GetSignInWithGoogleOption`, which the plugin sends when `useButtonFlow`
  /// is true — and `authenticate` is the method that sends it.
  ///
  /// It was briefly preceded by `attemptLightweightAuthentication`, on the
  /// theory that the passkey picker was the modern one. That call sends
  /// `useButtonFlow: false` and gets `GetGoogleIdOption` instead: the generic
  /// credential chooser, which lists whatever credentials the device happens to
  /// hold and is not the Google sign-in experience at all. Asking for it first
  /// meant the wrong sheet appeared, and then the right one on top of it.
  ///
  /// One sheet, and it is Google's.
  static Future<GoogleCredential> signIn() async {
    if (_desktop) return GoogleDesktopAuth.signIn();
    try {
      await _prepare();

      final GoogleSignInAccount account =
          await GoogleSignIn.instance.authenticate(scopeHint: scopes);
      // Kept, so the greeting and the account row never have to ask the plugin
      // anything — asking is what can prompt.
      await _write(_keyEmail, account.email);
      final String? display = account.displayName?.trim();
      if (display != null && display.isNotEmpty) {
        await _write(_keyName, display);
      }
      final String token = await _tokenFor(account, allowPrompt: true);
      final String? name = account.displayName?.trim();
      return (
        email: account.email,
        token: token,
        name: (name == null || name.isEmpty) ? null : name,
      );
    } on GoogleSignInException catch (error) {
      throw GoogleAuthException(describe(error));
    }
  }

  /// A fresh token for the account already signed in.
  ///
  /// The token expires in about an hour, so this is called when a connection is
  /// opened rather than when the account was added — which is also why nothing
  /// is stored: the token is fetched, used, and dropped.
  ///
  /// Returns null when there is no signed-in account. Throws with
  /// [GoogleAuthException.needsSignIn] when there is one but the grant no
  /// longer covers the scope, so the screen can offer the sign-in again rather
  /// than an error nobody can act on.
  static Future<String?> token() async {
    if (_desktop) return GoogleDesktopAuth.token();
    await _prepare();
    final GoogleSignInAccount? account = await _lightweight();
    if (account == null) return null;
    return _tokenFor(account, allowPrompt: false);
  }

  /// Signs out, so the next connection asks for an account again.
  static Future<void> forget() async {
    if (_desktop) return GoogleDesktopAuth.forget();
    await _prepare();
    // Signed out is signed out: a cached name would outlive the account.
    for (final String key in <String>[_keyEmail, _keyName]) {
      try {
        await _storage.delete(key: key);
      } catch (_) {
        // Nothing to do about it.
      }
    }
    try {
      await GoogleSignIn.instance.signOut();
    } on GoogleSignInException {
      // Already signed out, which is the state being asked for.
    }
  }

  /// The lightweight attempt, flattened.
  ///
  /// The plugin returns a *nullable future* here: null means the platform has
  /// no way to answer without UI and will report through a stream instead.
  /// Android always returns one, so a null is treated as "nobody signed in"
  /// rather than as a reason to wait for an event that is never coming.
  static Future<GoogleSignInAccount?> _lightweight() async {
    final Future<GoogleSignInAccount?>? attempt =
        GoogleSignIn.instance.attemptLightweightAuthentication();
    if (attempt == null) return null;
    try {
      return await attempt;
    } on GoogleSignInException {
      return null;
    }
  }

  /// A token for [account], from the cache if possible.
  ///
  /// [allowPrompt] is false on the reconnect path: a token that needs the user
  /// to look at a screen cannot be fetched from inside a connection, so that
  /// case is reported as needing a sign-in rather than silently opening a
  /// dialog nobody is looking at.
  static Future<String> _tokenFor(
    GoogleSignInAccount account, {
    required bool allowPrompt,
  }) async {
    final GoogleSignInAuthorizationClient client = account.authorizationClient;
    try {
      final GoogleSignInClientAuthorization? held =
          await client.authorizationForScopes(scopes);
      if (held != null) return held.accessToken;

      if (!allowPrompt) {
        throw const GoogleAuthException(
          'Google needs you to sign in again.',
          needsSignIn: true,
        );
      }

      final GoogleSignInClientAuthorization granted =
          await client.authorizeScopes(scopes);
      return granted.accessToken;
    } on GoogleSignInException catch (error) {
      throw GoogleAuthException(describe(error));
    }
  }

  /// What to say about a failure.
  ///
  /// Pure, and separate from the call, so the wording can be tested without a
  /// Google account. The codes that mean "you cancelled" say so; the one that
  /// means the project is misconfigured says what to check, because that is the
  /// failure a developer will actually hit and the plugin's own message does
  /// not point at the cause.
  static String describe(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Sign-in was cancelled.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Sign-in was interrupted. Try again.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google sign-in needs a screen, and there is not one available.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'This build is not registered with Google. The package name and '
            'the signing certificate have to be registered for this app in the '
            'Google Cloud project, and the client ID has to be a web one.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google refused the request: the project is missing something. '
            'Check that the Gmail API is enabled and that the consent screen '
            'lists the mail scope.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'That account is not the one this mailbox belongs to.';
      case GoogleSignInExceptionCode.unknownError:
        return 'Google sign-in failed. ${error.description ?? ''}'.trim();
    }
  }
}
