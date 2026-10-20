import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/ace_account.dart';

/// One stored account and its password.
typedef StoredAccount = ({AceAccount account, String password});

/// Persists every signed-in account in the platform keychain, so the app
/// reopens with all of them and can switch between them offline.
///
/// Best-effort by design: on a platform with no secure store, saving silently
/// no-ops and the app simply starts signed out rather than crashing.
class AccountStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _accountsKey = 'ace.accounts';
  static const String _passwordPrefix = 'ace.password.';

  String _passwordKey(String email) => '$_passwordPrefix$email';

  Future<List<StoredAccount>> loadAll() async {
    try {
      final String? raw = await _storage.read(key: _accountsKey);
      if (raw == null) return <StoredAccount>[];

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<StoredAccount> accounts = <StoredAccount>[];
      for (final dynamic entry in decoded) {
        final AceAccount account =
            AceAccount.fromJson(entry as Map<String, dynamic>);
        final String? password = await _storage.read(key: _passwordKey(account.email));
        if (password != null) {
          accounts.add((account: account, password: password));
        }
      }
      return accounts;
    } catch (_) {
      return <StoredAccount>[];
    }
  }

  Future<void> saveAll(List<StoredAccount> accounts) async {
    try {
      final Set<String> keep =
          accounts.map((StoredAccount a) => a.account.email).toSet();

      // Drop passwords for accounts that are no longer stored.
      final String? raw = await _storage.read(key: _accountsKey);
      if (raw != null) {
        for (final dynamic entry in jsonDecode(raw) as List<dynamic>) {
          final String email =
              (entry as Map<String, dynamic>)['email'] as String;
          if (!keep.contains(email)) {
            await _storage.delete(key: _passwordKey(email));
          }
        }
      }

      await _storage.write(
        key: _accountsKey,
        value: jsonEncode(
          accounts.map((StoredAccount a) => a.account.toJson()).toList(),
        ),
      );
      for (final StoredAccount a in accounts) {
        await _storage.write(
          key: _passwordKey(a.account.email),
          value: a.password,
        );
      }
    } catch (_) {
      // No keychain available; stay signed out next launch.
    }
  }

  Future<void> clear() async {
    try {
      final String? raw = await _storage.read(key: _accountsKey);
      if (raw != null) {
        for (final dynamic entry in jsonDecode(raw) as List<dynamic>) {
          final String email =
              (entry as Map<String, dynamic>)['email'] as String;
          await _storage.delete(key: _passwordKey(email));
        }
      }
      await _storage.delete(key: _accountsKey);
    } catch (_) {
      // Nothing stored.
    }
  }
}
