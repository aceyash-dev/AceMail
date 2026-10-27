import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/ace_account.dart';
import 'vault.dart';

/// One stored account and its password.
typedef StoredAccount = ({AceAccount account, String password});

/// The outcome of reading stored accounts. [error] is non-null when something
/// went wrong — a record that will not open, or one whose password is missing —
/// so the app can say so instead of silently starting signed out.
typedef AccountLoad = ({List<StoredAccount> accounts, String? error});

/// Persists every signed-in account, and its password, on this device.
///
/// **AES-256-GCM, one sealed file.** The whole set — the account list, the
/// passwords, which account was in front — is one JSON record, sealed by
/// [AceVault]: a fresh 12-byte nonce per write, a 128-bit tag, and a key that
/// lives in the platform keychain (see [DeviceKeyStore] for what happens when
/// the keychain will not answer). A record that has been edited, truncated or
/// moved fails to open rather than opening as something else, and the file is
/// replaced by writing beside it and renaming over it, so a crash mid-write
/// leaves the previous record whole.
///
/// This used to be the keychain alone: a manifest entry, and one entry per
/// password. The keychain is the right place for *a* secret and the wrong place
/// for a *list* of them — one entry that will not read is one account lost, and
/// on a machine where the secret service is not running (a desktop session
/// before the keyring unlocks, a keystore that refuses at boot) every read came
/// back empty and the app asked for the password again on every start. One
/// sealed file has one failure mode instead of N, and it is a failure this can
/// report.
class AccountStore {
  AccountStore({Directory? directory, AceVault? vault, KeyStore? legacy})
      : _directory = directory,
        _vault = vault,
        _legacy = legacy ?? const KeychainKeyStore();

  /// The record's filename inside the credentials directory.
  static const String _fileName = 'credentials.ace';

  /// Bound into the tag, so a record sealed for something else — a cached
  /// message, say — cannot be passed off as this one.
  static const String _aad = 'ace.credentials';

  /// The shape of the record. Bumped only when a reader has to treat an older
  /// record differently, which nothing does yet.
  static const int _recordVersion = 2;

  // --- the layout this replaced, read once and then dropped ----------------

  static const String _legacyManifestKey = 'ace.accounts';
  static const String _legacyPasswordPrefix = 'ace.password.';
  static const String _legacyActiveKey = 'ace.active';

  /// Where the file goes. Injected by a test; resolved from the platform
  /// otherwise, because the app's own support directory is the one place a
  /// record like this belongs — it is private to the app and it goes when the
  /// app goes.
  final Directory? _directory;

  final AceVault? _vault;

  /// Where the previous layout's records are read from, on the first start
  /// after the update. Nothing writes here any more.
  final KeyStore _legacy;

  Directory? _resolved;
  AceVault? _opened;

  Future<Directory> _dir() async {
    final Directory? fixed = _directory;
    if (fixed != null) return fixed;
    final Directory? cached = _resolved;
    if (cached != null) return cached;
    return _resolved = Directory(
      '${(await getApplicationSupportDirectory()).path}/credentials',
    );
  }

  /// The vault, which is the keychain plus a key file behind it. Its own
  /// namespace, so it never mints or rotates the key the message cache uses.
  Future<AceVault> _openVault() async {
    final AceVault? fixed = _vault;
    if (fixed != null) return fixed;
    final AceVault? opened = _opened;
    if (opened != null) return opened;
    final Directory directory = await _dir();
    return _opened = AceVault(
      keys: DeviceKeyStore(directory: directory),
      namespace: 'ace.credentials',
    );
  }

  Future<File> _file() async => File('${(await _dir()).path}/$_fileName');

  /// The record, or null when there is not one yet.
  ///
  /// Throws [AceVaultException] when the file is there but will not open: a
  /// missing key, an altered record. The caller turns that into a sentence
  /// rather than into a silent sign-out.
  Future<Map<String, Object?>?> _readRecord() async {
    final File file = await _file();
    if (!await file.exists()) return null;
    final Uint8List sealed = await file.readAsBytes();
    final AceVault vault = await _openVault();
    final Uint8List plain = await vault.open(sealed, aad: _aad);
    final Object? decoded = jsonDecode(utf8.decode(plain));
    if (decoded is! Map<String, Object?>) {
      throw const AceVaultException('The saved credentials are not a record.');
    }
    return decoded;
  }

  Future<void> _writeRecord(Map<String, Object?> record) async {
    final File file = await _file();
    await file.parent.create(recursive: true);
    final AceVault vault = await _openVault();
    final Uint8List sealed = await vault.seal(
      Uint8List.fromList(utf8.encode(jsonEncode(record))),
      aad: _aad,
    );
    // Beside and renamed over: a half-written record that opens as nothing is
    // worse than an old record that opens as what it was.
    final File temp = File('${file.path}.new');
    await temp.writeAsBytes(sealed, flush: true);
    await temp.rename(file.path);
  }

  /// Moves an unopenable record out of the way, under a name that says what it
  /// is.
  ///
  /// Not deleted: a record that will not open is still the only copy of
  /// somebody's account list, and a key that comes back — a restored keychain, a
  /// fixed build — opens it again. It only has to stop being the file the next
  /// save overwrites.
  Future<void> _keepAside() async {
    try {
      final File file = await _file();
      if (!await file.exists()) return;
      int suffix = 1;
      File target = File('${file.path}.kept');
      while (await target.exists()) {
        suffix++;
        target = File('${file.path}.kept$suffix');
      }
      await file.rename(target.path);
    } catch (_) {
      // Nothing to move, or nowhere to move it. The error is already on its way
      // to the screen either way.
    }
  }

  /// The account that was in front last time, so a restart lands back on it.
  Future<String?> loadActiveEmail() async {
    try {
      return (await _readRecord())?['active'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveActiveEmail(String? email) async {
    try {
      final Map<String, Object?> record =
          await _readRecord() ??
              <String, Object?>{
                'version': _recordVersion,
                'accounts': <Object?>[],
              };
      record['active'] = email;
      await _writeRecord(record);
    } catch (_) {
      // Not worth interrupting the user for; the account order still stands.
    }
  }

  Future<AccountLoad> loadAll() async {
    final Map<String, Object?>? record;
    try {
      record = await _readRecord();
    } on AceVaultException catch (error) {
      // The record is there and will not open: the key it was sealed with is
      // gone, or the record has been altered. Either way the accounts are not
      // lost *yet* — the bytes are still on the disk — so the record is kept
      // and the next sign-in writes beside it rather than over it.
      await _keepAside();
      // One more chance: a device that updated but never finished migrating may
      // still have the old keychain entries, which are readable without a key.
      final AccountLoad legacy = await _migrate();
      if (legacy.accounts.isNotEmpty) return legacy;
      return (
        accounts: <StoredAccount>[],
        error: 'The accounts saved on this device could not be opened '
            '($error). They have been kept rather than deleted. Sign in again '
            'to use the app.',
      );
    } catch (_) {
      return (
        accounts: <StoredAccount>[],
        error: 'The accounts saved on this device could not be read, so none '
            'were loaded. Sign in again to continue.',
      );
    }

    // Nothing sealed yet: the first start after the update, which is the one
    // time the old keychain layout is worth asking about.
    if (record == null) return _migrate();

    final List<StoredAccount> accounts = <StoredAccount>[];
    final List<String> incomplete = <String>[];

    for (final Object? entry
        in record['accounts'] as List<Object?>? ?? const <Object?>[]) {
      if (entry is! Map<String, Object?>) continue;
      final Object? json = entry['account'];
      if (json is! Map<String, Object?>) continue;

      final AceAccount account;
      try {
        account = AceAccount.fromJson(Map<String, dynamic>.from(json));
      } catch (_) {
        continue;
      }

      // A Google account has no password to read, and a missing one is the
      // expected state rather than a broken record. It is why this cannot be
      // inferred from the file: "no password stored" means two opposite things
      // depending on how the account signs in.
      if (account.isGoogle) {
        accounts.add((account: account, password: ''));
        continue;
      }

      final String? password = entry['password'] as String?;
      // A record whose password is gone is incomplete, not absent: say so
      // rather than quietly dropping the account.
      if (password == null || password.isEmpty) {
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
      // The active account rides along in the same record: one write instead of
      // two, and no window where the file names an account it does not hold.
      String? active;
      Map<String, Object?>? previous;
      try {
        previous = await _readRecord();
        active = previous?['active'] as String?;
      } catch (_) {
        // An unreadable record is being replaced by this one anyway.
        active = null;
      }

      // Passwords already on the device, by address. A session that has not
      // been given a password yet holds an empty string, and writing that over
      // a good one is how an account is signed out by a save nobody asked for:
      // the next start reads the record, finds a blank password, and treats the
      // account as one it cannot restore.
      final Map<String, String> known = <String, String>{};
      for (final Object? entry
          in previous?['accounts'] as List<Object?>? ?? const <Object?>[]) {
        if (entry is! Map<String, Object?>) continue;
        final Object? json = entry['account'];
        if (json is! Map<String, Object?>) continue;
        final Object? email = json['email'];
        final Object? password = entry['password'];
        if (email is String && password is String && password.isNotEmpty) {
          known[email.toLowerCase()] = password;
        }
      }

      await _writeRecord(<String, Object?>{
        'version': _recordVersion,
        'active': active,
        'accounts': <Map<String, Object?>>[
          for (final StoredAccount a in accounts)
            <String, Object?>{
              'account': a.account.toJson(),
              // A Google account is stored with no password at all rather than
              // with an empty one: a field holding nothing says a secret exists
              // and is blank, which is a different claim. Any other account
              // keeps the password it already had rather than being blanked.
              'password': a.account.isGoogle
                  ? null
                  : (a.password.isNotEmpty
                      ? a.password
                      : known[a.account.email.toLowerCase()]),
            },
        ],
      });

      // Read it back. A save that returns success without the record opening
      // again is the failure this whole file exists to prevent — and it is
      // invisible until the next launch, when it looks like being signed out
      // for no reason. One read is cheap next to that.
      final Map<String, Object?>? check = await _readRecord();
      if (check == null) {
        return 'The account was saved but could not be read back. It may not '
            'be remembered next time.';
      }
      return null;
    } catch (_) {
      return 'This device could not save the account, so it will not be '
          'remembered next time.';
    }
  }

  /// Returns null on success, or a reason the credentials were not removed.
  ///
  /// The key goes with the record. Deleting the file and leaving the key behind
  /// would leave a key to nothing, and a later record would open with it.
  Future<String?> clear() async {
    try {
      final File file = await _file();
      if (await file.exists()) await file.delete();
      await (await _openVault()).clear();
      await _forgetLegacy(await _legacyEmails());
      return null;
    } catch (_) {
      return 'The saved credentials could not be removed from this device.';
    }
  }

  // --- the previous layout -------------------------------------------------

  /// Reads the keychain manifest and its passwords, then seals what it found
  /// into the file and drops the old entries.
  ///
  /// This exists so an update does not sign anybody out. It runs once: after it
  /// the file is there, and `loadAll` never looks at the keychain again.
  Future<AccountLoad> _migrate() async {
    final String? raw;
    try {
      raw = await _legacy.read(_legacyManifestKey);
    } catch (_) {
      return (
        accounts: <StoredAccount>[],
        error: 'This device\'s keychain could not be read, so saved accounts '
            'were not loaded. Sign in again to continue.',
      );
    }
    if (raw == null || raw.trim().isEmpty) {
      return (accounts: <StoredAccount>[], error: null);
    }

    List<Map<String, Object?>> entries;
    try {
      entries = _decodeLegacy(raw);
    } catch (_) {
      return (
        accounts: <StoredAccount>[],
        error: 'The saved account list could not be read. Sign in again.',
      );
    }

    final List<StoredAccount> accounts = <StoredAccount>[];
    final List<String> incomplete = <String>[];

    for (final Map<String, Object?> entry in entries) {
      final AceAccount account;
      try {
        account = AceAccount.fromJson(Map<String, dynamic>.from(entry));
      } catch (_) {
        continue;
      }

      if (account.isGoogle) {
        accounts.add((account: account, password: ''));
        continue;
      }

      final String? password;
      try {
        password = await _legacy.read('$_legacyPasswordPrefix${account.email}');
      } catch (_) {
        incomplete.add(account.email);
        continue;
      }
      if (password == null) {
        incomplete.add(account.email);
        continue;
      }
      accounts.add((account: account, password: password));
    }

    if (accounts.isNotEmpty) {
      // Sealed before the old copy is dropped: if the write fails, the keychain
      // entries are still there and the next start tries again.
      final String? failure = await saveAll(accounts);
      if (failure == null) {
        try {
          final String? active = await _legacy.read(_legacyActiveKey);
          if (active != null) await saveActiveEmail(active);
        } catch (_) {
          // Which account opens first is a nicety next to the passwords.
        }
        await _forgetLegacy(entries.map((Map<String, Object?> e) => e['email'])
            .whereType<String>()
            .toList());
      }
    }

    return (
      accounts: accounts,
      error: incomplete.isEmpty
          ? null
          : 'The saved password for ${incomplete.join(', ')} could not be '
              'read. Sign in again to restore it.',
    );
  }

  Future<List<String>> _legacyEmails() async {
    try {
      final String? raw = await _legacy.read(_legacyManifestKey);
      if (raw == null) return <String>[];
      return _decodeLegacy(raw)
          .map((Map<String, Object?> e) => e['email'])
          .whereType<String>()
          .toList();
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> _forgetLegacy(List<String> emails) async {
    for (final String email in emails) {
      try {
        await _legacy.delete('$_legacyPasswordPrefix$email');
      } catch (_) {
        // A keychain that will not delete is not a reason to fail a save.
      }
    }
    for (final String key in <String>[_legacyManifestKey, _legacyActiveKey]) {
      try {
        await _legacy.delete(key);
      } catch (_) {
        // Same.
      }
    }
  }

  /// Accepts the old `{version, accounts}` manifest and the older bare array,
  /// so an upgrade does not lose anyone's accounts.
  static List<Map<String, Object?>> _decodeLegacy(String raw) {
    final Object? decoded = jsonDecode(raw);
    final List<dynamic> list = decoded is Map<String, dynamic>
        ? (decoded['accounts'] as List<dynamic>? ?? <dynamic>[])
        : decoded as List<dynamic>;
    return list.whereType<Map<String, Object?>>().toList(growable: false);
  }
}
