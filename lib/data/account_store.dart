import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/ace_account.dart';

/// One stored account and its password.
typedef StoredAccount = ({AceAccount account, String password});

/// The outcome of reading stored accounts. [error] is non-null when something
/// went wrong — an unreadable keychain, or a record whose password is missing —
/// so the app can say so instead of silently starting signed out.
typedef AccountLoad = ({List<StoredAccount> accounts, String? error});

/// Persists every signed-in account in the platform keychain, so the app
/// reopens with all of them and can switch between them offline.
///
/// Writes a versioned manifest, and reports failure rather than swallowing it:
/// a user who is told an account was remembered should be able to rely on it.
class AccountStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _accountsKey = 'ace.accounts';
  static const String _passwordPrefix = 'ace.password.';
  static const String _activeKey = 'ace.active';
  static const int _manifestVersion = 1;

  String _passwordKey(String email) => '$_passwordPrefix$email';

  /// The account that was in front last time, so a restart lands back on it.
  Future<String?> loadActiveEmail() async {
    try {
      return await _storage.read(key: _activeKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveActiveEmail(String? email) async {
    try {
      if (email == null) {
        await _storage.delete(key: _activeKey);
      } else {
        await _storage.write(key: _activeKey, value: email);
      }
    } catch (_) {
      // Not worth interrupting the user for; the account order still stands.
    }
  }

  Future<AccountLoad> loadAll() async {
    final String? raw;
    try {
      raw = await _storage.read(key: _accountsKey);
    } catch (_) {
      return (
        accounts: <StoredAccount>[],
        error: 'This device\'s keychain could not be read, so saved accounts '
            'were not loaded. Sign in again to continue.',
      );
    }
    if (raw == null) return (accounts: <StoredAccount>[], error: null);

    List<Map<String, dynamic>> entries;
    try {
      entries = _decodeManifest(raw);
    } catch (_) {
      return (
        accounts: <StoredAccount>[],
        error: 'The saved account list could not be read. Sign in again.',
      );
    }

    final List<StoredAccount> accounts = <StoredAccount>[];
    final List<String> incomplete = <String>[];

    for (final Map<String, dynamic> entry in entries) {
      final AceAccount account;
      try {
        account = AceAccount.fromJson(entry);
      } catch (_) {
        continue;
      }

      // A Google account has no password to read, and a missing one is the
      // expected state rather than a broken record. It is why this cannot be
      // inferred from the keychain: "no password stored" means two opposite
      // things depending on how the account signs in.
      if (account.isGoogle) {
        accounts.add((account: account, password: ''));
        continue;
      }

      final String? password;
      try {
        password = await _storage.read(key: _passwordKey(account.email));
      } catch (_) {
        incomplete.add(account.email);
        continue;
      }

      // A record whose password is gone is incomplete, not absent: say so
      // rather than quietly dropping the account.
      if (password == null) {
        incomplete.add(account.email);
        continue;
      }
      accounts.add((account: account, password: password));
    }

    return (
      accounts: accounts,
      error: incomplete.isEmpty
          ? null
          : 'The saved password for ${incomplete.join(', ')} could not be '
              'read. Sign in again to restore it.',
    );
  }

  /// Returns null on success, or a reason the credentials were not stored.
  Future<String?> saveAll(List<StoredAccount> accounts) async {
    try {
      final Set<String> keep =
          accounts.map((StoredAccount a) => a.account.email).toSet();

      // Drop passwords for accounts that are no longer stored.
      final String? raw = await _storage.read(key: _accountsKey);
      if (raw != null) {
        for (final Map<String, dynamic> entry in _decodeManifest(raw)) {
          final String? email = entry['email'] as String?;
          if (email != null && !keep.contains(email)) {
            await _storage.delete(key: _passwordKey(email));
          }
        }
      }

      // Passwords first: a manifest that names an account whose password was
      // never written is the incomplete state we are trying to avoid. A Google
      // account is skipped rather than written with an empty string — a key
      // holding nothing is a record that says a secret exists and is blank.
      for (final StoredAccount a in accounts) {
        if (a.account.isGoogle) continue;
        await _storage.write(
          key: _passwordKey(a.account.email),
          value: a.password,
        );
      }

      await _storage.write(
        key: _accountsKey,
        value: jsonEncode(<String, dynamic>{
          'version': _manifestVersion,
          'accounts': accounts
              .map((StoredAccount a) => a.account.toJson())
              .toList(),
        }),
      );
      return null;
    } catch (_) {
      return 'This device could not save the account, so it will not be '
          'remembered next time.';
    }
  }

  /// Returns null on success, or a reason the credentials were not removed.
  Future<String?> clear() async {
    try {
      final String? raw = await _storage.read(key: _accountsKey);
      if (raw != null) {
        for (final Map<String, dynamic> entry in _decodeManifest(raw)) {
          final String? email = entry['email'] as String?;
          if (email != null) {
            await _storage.delete(key: _passwordKey(email));
          }
        }
      }
      await _storage.delete(key: _accountsKey);
      await _storage.delete(key: _activeKey);
      return null;
    } catch (_) {
      return 'The saved credentials could not be removed from this device.';
    }
  }

  /// Accepts the current `{version, accounts}` manifest and the older bare
  /// array, so an upgrade does not lose anyone's accounts.
  static List<Map<String, dynamic>> _decodeManifest(String raw) {
    final Object? decoded = jsonDecode(raw);
    final List<dynamic> list = decoded is Map<String, dynamic>
        ? (decoded['accounts'] as List<dynamic>? ?? <dynamic>[])
        : decoded as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }
}
