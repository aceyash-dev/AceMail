import 'dart:convert';
import 'dart:io';
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

/// The keychain, with a key file behind it.
///
/// The keychain is where a key belongs. It is also, on some machines, not
/// there: a desktop with no secret service running, a Linux session before the
/// keyring is unlocked, a device whose keystore refuses the write. The failure
/// is silent — `read` comes back null — and the visible symptom is an app that
/// asks for your password on every start, because the key that would have
/// opened your saved accounts is gone.
///
/// So the key is written to both places and read from whichever answers first.
/// The file sits in the app's own directory, mode `0600`, which is the same
/// protection the rest of the app's data has. That is a real trade — a key on
/// the same disk as the records it opens is weaker than a key the OS holds —
/// and it is the right one here, because the alternative is not a stronger key.
/// It is no stored credentials at all.
class DeviceKeyStore implements KeyStore {
  DeviceKeyStore({required Directory directory, KeyStore? keychain})
      : _directory = directory,
        _keychain = keychain ?? const KeychainKeyStore();

  final Directory _directory;
  final KeyStore _keychain;

  File _fileFor(String key) => File('${_directory.path}/$key.key');

  @override
  Future<String?> read(String key) async {
    try {
      final String? value = await _keychain.read(key);
      if (value != null && value.isNotEmpty) return value;
    } catch (_) {
      // The keychain is unavailable; the file below is why that is survivable.
    }
    try {
      final File file = _fileFor(key);
      if (!await file.exists()) return null;
      final String value = (await file.readAsString()).trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    Object? keychainError;
    try {
      await _keychain.write(key, value);
    } catch (error) {
      keychainError = error;
    }

    // Written either way. A keychain that works today and is wiped tomorrow
    // (a reset, a restore onto a new device, a moved profile) would otherwise
    // take every saved account with it, which is the bug this exists to fix.
    try {
      await _directory.create(recursive: true);
      final File file = _fileFor(key);
      await file.writeAsString(value, flush: true);
      await _restrict(file);
    } catch (_) {
      // If neither place took it, the caller finds out when it cannot open a
      // record, and says so — which is better than a silent half-write.
      if (keychainError != null) throw keychainError;
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _keychain.delete(key);
    } catch (_) {
      // Gone either way is what the caller asked for.
    }
    try {
      final File file = _fileFor(key);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Nothing to remove, or nothing that would let us remove it.
    }
  }

  /// `0600` on the key file. Windows ignores the mode, and its app data lives
  /// in a per-user directory anyway.
  static Future<void> _restrict(File file) async {
    if (Platform.isWindows) return;
    try {
      await Process.run('chmod', <String>['600', file.path]);
    } catch (_) {
      // Best effort: the directory is already the app's own.
    }
  }
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
  AceVault({
    KeyStore? keys,
    Random? random,
    // Which set of keys this vault uses. Two vaults that share a keychain and
    // a directory — the cache and the saved credentials, say — would otherwise
    // mint and rotate the same key under the same name.
    String namespace = 'ace.vault',
  })  : _keys = keys ?? const KeychainKeyStore(),
        _random = random ?? Random.secure(),
        _namespace = namespace;

  /// The current record format. A record whose first byte is not this is
  /// refused rather than guessed at, which is what makes a future change safe.
  static const int formatVersion = 1;

  /// 96 bits, the size GCM is defined for and the size that needs no hashing.
  static const int nonceLength = 12;

  static const int _keyLength = 32;
  static const int _tagBits = 128;
  static const int _maxVersion = 255;

  final String _namespace;
  String get _currentKey => '$_namespace.keyVersion';
  String _keyName(int version) => '$_namespace.key.$version';

  final KeyStore _keys;
  final Random _random;

  Uint8List _randomBytes(int length) {
    final Uint8List bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  /// The version being minted right now, if one is.
  ///
  /// Two first writes can arrive together — a message body and its metadata,
  /// say — and both find an empty vault. Both then mint version 1, and the
  /// second write replaces the key the first has already sealed with. That
  /// record can never be opened again. One in-flight mint, shared, is what
  /// stops it; the same shape as the sign-in guard, for the same reason.
  Future<int>? _minting;

  /// The key version new records are sealed with, minting one on first use.
  Future<int> currentVersion() async {
    final int? version = int.tryParse(await _keys.read(_currentKey) ?? '');
    if (version != null && await _keys.read(_keyName(version)) != null) {
      return version;
    }
    // Cleared when it finishes, success or failure, so a keychain that refused
    // once is asked again rather than being poisoned for the session.
    return _minting ??= _mintFirst().whenComplete(() => _minting = null);
  }

  /// Mints version 1, unless somebody else got there first.
  ///
  /// Re-checked inside the guard: a caller that started before the winner
  /// finished would otherwise mint over the key the winner is already using.
  Future<int> _mintFirst() async {
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
  ///
  /// Deliberately does **not** mint a key when there is none: this is a
  /// question, and asking it must not change the answer.
  Future<List<int>> readableVersions() async {
    final int? current = int.tryParse(await _keys.read(_currentKey) ?? '');
    if (current == null) return <int>[];
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
