import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// What the app needs from the platform keychain.
///
/// An interface of our own rather than the plugin's class, for one reason: the
/// behaviour worth testing here is what happens when storage *fails*, and that
/// cannot be reached through the real one. A test can hand a store that throws
/// on read, or refuses a write, and see what the caller concludes.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  /// Every entry, for the cleanups that have to find keys they did not write
  /// down — a token cached for an address nobody remembers signing in as is a
  /// token that cannot otherwise be deleted.
  Future<Map<String, String>> readAll();
}

/// The platform keychain: Keystore on Android, the Keychain on Apple's
/// platforms, libsecret on Linux, the credential store on Windows.
class KeychainSecretStore implements SecretStore {
  const KeychainSecretStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();
}
