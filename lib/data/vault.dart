import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

/// Where the vault keeps its keys.
///
/// Deliberately narrow: the keychain is the only thing the vault needs from the
/// platform, and a test can supply a map instead of a plugin channel.
abstract interface class KeyStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// The real one: the platform keychain, through `flutter_secure_storage`.
class KeychainKeyStore implements KeyStore {
  const KeychainKeyStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// The app's local cache, sealed.
///
/// Everything Ace Mail keeps on the device — drafts, cached message bodies,
/// cached headers — goes through here, so "is it encrypted?" is answered in one
/// place instead of once per feature.
///
/// The cipher is **AES-256-GCM**: authenticated, so a record that has been
/// altered or truncated fails to open rather than opening as something else.
/// The nonce is **12 random bytes per record**, drawn from the platform CSPRNG
/// and stored beside the ciphertext. A counter would be smaller and faster, but
/// it needs durable state that survives a reinstall and a crash; getting that
/// wrong repeats a nonce, which is the one mistake GCM does not survive. Random
/// 96-bit nonces are the safe choice at the scale of one mailbox on one phone.
///
/// Keys are **versioned**. The key lives in the platform keychain, tagged with
/// the version it belongs to, and every record carries that version:
///
/// ```
///   byte  0        1        2 .. 13        14 ..
///        ┌────────┬────────┬────────────┬────────────────────┐
///        │ format │ keyVer │   nonce    │ ciphertext ‖ tag   │
///        └────────┴────────┴────────────┴────────────────────┘
/// ```
///
/// A rotation mints a new key, leaves the old ones in place for reading, and
/// lets records move across as they are rewritten. [rotate] does not rewrite
/// anything itself — the caller holds the records — but nothing becomes
/// unreadable when it runs.
class AceVault {
  AceVault({KeyStore? keys, Random? random})
      : _keys = keys ?? const KeychainKeyStore(),
        _random = random ?? Random.secure();

  /// The current record format. A record whose first byte is not this is
  /// refused rather than guessed at, which is what makes a future change safe.
  static const int formatVersion = 1;

  /// 96 bits, the size GCM is defined for and the size that needs no hashing.
  static const int nonceLength = 12;

  static const int _keyLength = 32;
  static const int _tagBits = 128;
  static const int _maxVersion = 255;

  static const String _currentKey = 'ace.vault.keyVersion';
  static String _keyName(int version) => 'ace.vault.key.$version';

  final KeyStore _keys;
  final Random _random;

  Uint8List _randomBytes(int length) {
    final Uint8List bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  /// The key version new records are sealed with, minting one on first use.
  Future<int> currentVersion() async {
    final int? version = int.tryParse(await _keys.read(_currentKey) ?? '');
    if (version != null && await _keys.read(_keyName(version)) != null) {
      return version;
    }
    return _mint(1);
  }

  Future<Uint8List> _keyFor(int version) async {
    final String? raw = await _keys.read(_keyName(version));
    if (raw == null) {
      throw AceVaultException('The key for version $version is gone.');
    }
    final Uint8List key = base64Decode(raw);
    if (key.length != _keyLength) {
      throw AceVaultException(
        'The key for version $version is ${key.length} bytes, not $_keyLength.',
      );
    }
    return key;
  }

  Future<int> _mint(int version) async {
    await _keys.write(_keyName(version), base64Encode(_randomBytes(_keyLength)));
    await _keys.write(_currentKey, '$version');
    return version;
  }

  /// Seals [plain].
  ///
  /// [aad] is authenticated but not stored, so a caller can bind a record to
  /// where it belongs — a body to its folder and uid — and a record that has
  /// been moved somewhere else will not open.
  Future<Uint8List> seal(Uint8List plain, {String aad = ''}) async {
    final int version = await currentVersion();
    final Uint8List key = await _keyFor(version);
    final Uint8List nonce = _randomBytes(nonceLength);

    final GCMBlockCipher cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(key), _tagBits, nonce, utf8.encode(aad)),
      );

    return (BytesBuilder(copy: false)
          ..addByte(formatVersion)
          ..addByte(version)
          ..add(nonce)
          ..add(cipher.process(plain)))
        .takeBytes();
  }

  /// Opens a record [seal] produced.
  ///
  /// Throws [AceVaultException] when the bytes are not a record, when the key
  /// is missing, or when the tag does not check out — which is what an altered
  /// or truncated record looks like. A caller can treat all three the same way:
  /// the record is gone, so fetch it again.
  Future<Uint8List> open(Uint8List sealed, {String aad = ''}) async {
    if (sealed.length < 2 + nonceLength) {
      throw const AceVaultException('That is not a sealed record.');
    }
    if (sealed[0] != formatVersion) {
      throw AceVaultException(
        'A record in format ${sealed[0]} cannot be read by this build.',
      );
    }
    final int version = sealed[1];
    final Uint8List nonce = Uint8List.sublistView(sealed, 2, 2 + nonceLength);
    final Uint8List body = Uint8List.sublistView(sealed, 2 + nonceLength);
    final Uint8List key = await _keyFor(version);

    try {
      final GCMBlockCipher cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(KeyParameter(key), _tagBits, nonce, utf8.encode(aad)),
        );
      return cipher.process(body);
    } on InvalidCipherTextException {
      throw const AceVaultException(
        'That record did not authenticate, so it was not opened.',
      );
    }
  }

  /// Mints a new key and makes it current.
  ///
  /// Records sealed under older versions keep opening: their version still
  /// points at the key that sealed them. Nothing is rewritten here — a rotation
  /// is a promise that the old key stays readable, not a bulk re-encryption
  /// that would have to be atomic to be safe.
  Future<int> rotate() async {
    final int next = (await currentVersion()) + 1;
    if (next > _maxVersion) {
      throw const AceVaultException('The key version has run out of room.');
    }
    return _mint(next);
  }

  /// The versions this vault can still read, oldest first. For a caller that
  /// wants to re-seal old records under the current key.
  Future<List<int>> readableVersions() async {
    final int current = await currentVersion();
    final List<int> found = <int>[];
    for (int version = 1; version <= current; version++) {
      if (await _keys.read(_keyName(version)) != null) found.add(version);
    }
    return found;
  }

  /// Forgets every key, which makes every sealed record unreadable — the
  /// thorough way to destroy the cache, without trusting a file delete.
  Future<void> clear() async {
    final List<int> versions = await readableVersions();
    for (final int version in versions) {
      await _keys.delete(_keyName(version));
    }
    await _keys.delete(_currentKey);
  }
}

/// Something the vault refused to do, with the reason in plain words.
class AceVaultException implements Exception {
  const AceVaultException(this.message);

  final String message;

  @override
  String toString() => message;
}
