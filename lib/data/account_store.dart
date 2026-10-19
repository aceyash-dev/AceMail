import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/ace_account.dart';

/// Persists account settings and the password in the platform keychain, so the
/// app reopens signed in. Best-effort by design: on a platform with no secure
/// store, saving silently no-ops and the app simply starts signed out rather
/// than crashing.
class AccountStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _settingsKey = 'ace.account';
  static const String _passwordKey = 'ace.password';

  Future<void> save(AceAccount account, String password) async {
    try {
      await _storage.write(
        key: _settingsKey,
        value: jsonEncode(account.toJson()),
      );
      await _storage.write(key: _passwordKey, value: password);
    } catch (_) {
      // No keychain available; stay signed out next launch.
    }
  }

  Future<({AceAccount account, String password})?> load() async {
    try {
      final String? raw = await _storage.read(key: _settingsKey);
      final String? password = await _storage.read(key: _passwordKey);
      if (raw == null || password == null) return null;
      return (
        account: AceAccount.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        password: password,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _settingsKey);
      await _storage.delete(key: _passwordKey);
    } catch (_) {
      // Nothing stored.
    }
  }
}
