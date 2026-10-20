import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small, non-secret app preferences.
///
/// Kept in the same store as the accounts because it is already there and is
/// available on every platform — nothing here is sensitive.
class Preferences extends ChangeNotifier {
  Preferences({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _showAvatarsKey = 'ace.showAvatars';

  final FlutterSecureStorage _storage;

  bool _showAvatars = false;

  /// Whether sender pictures are fetched from Gravatar.
  ///
  /// **Off by default, and deliberately so.** A Gravatar lookup sends an MD5 of
  /// every sender's address to a third party. A hash of an address is not
  /// anonymous — addresses are guessable and can be hashed by anyone — so this
  /// is a disclosure the user opts into, not one the app makes for them. When
  /// it is off, no network request is made at all.
  bool get showAvatars => _showAvatars;

  Future<void> load() async {
    try {
      final String? stored = await _storage.read(key: _showAvatarsKey);
      if (stored != null) _showAvatars = stored == 'true';
    } catch (_) {
      // Fall back to the default.
    }
    notifyListeners();
  }

  Future<void> setShowAvatars(bool value) async {
    if (_showAvatars == value) return;
    _showAvatars = value;
    notifyListeners();
    try {
      await _storage.write(key: _showAvatarsKey, value: '$value');
    } catch (_) {
      // Preference will not survive a restart.
    }
  }
}
