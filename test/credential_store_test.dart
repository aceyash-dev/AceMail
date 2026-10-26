import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ace_mail/data/account_store.dart';
import 'package:ace_mail/data/vault.dart';
import 'package:ace_mail/models/ace_account.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

/// A keychain in a map, so the store can be tested without a plugin channel.
class MemoryKeys implements KeyStore {
  MemoryKeys({this.refuse = false});

  /// A keychain that will not answer: every call throws, which is what a
  /// desktop with no secret service running does.
  final bool refuse;

  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async {
    if (refuse) throw StateError('no keychain here');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (refuse) throw StateError('no keychain here');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (refuse) throw StateError('no keychain here');
    values.remove(key);
  }
}

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('ace-credentials');
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  /// A store over [directory]. [legacy] is the keychain the old layout wrote to.
  AccountStore storeOn(
    MemoryKeys vaultKeys, {
    KeyStore? legacy,
  }) =>
      AccountStore(
        directory: directory,
        vault: AceVault(
          keys: vaultKeys,
          random: Random(4),
          namespace: 'ace.credentials',
        ),
        legacy: legacy ?? MemoryKeys(),
      );

  File recordFile() =>
      File('${directory.path}/credentials.ace');

  group('saved credentials', () {
    test('round trip through the sealed file', () async {
      final MemoryKeys keys = MemoryKeys();
      expect(
        await storeOn(keys).saveAll(<StoredAccount>[
          (account: accountA, password: 'hunter2'),
        ]),
        isNull,
      );

      final AccountLoad loaded = await storeOn(keys).loadAll();

      expect(loaded.error, isNull);
      expect(loaded.accounts.length, 1);
      expect(loaded.accounts.single.account.email, accountA.email);
      expect(loaded.accounts.single.password, 'hunter2');
    });

    test('nothing readable is on the disk', () async {
      await storeOn(MemoryKeys()).saveAll(<StoredAccount>[
        (account: accountA, password: 'hunter2'),
      ]);

      // latin1 rather than utf8: a sealed record is bytes, not text, and a
      // decoder that refuses to read them proves nothing about what is in them.
      final String raw = latin1.decode(recordFile().readAsBytesSync());
      expect(raw.contains('hunter2'), isFalse);
      expect(raw.contains(accountA.email), isFalse);
      expect(raw.contains(accountA.imapHost), isFalse);
    });

    test('a restart finds the accounts without asking anyone', () async {
      // Two separate stores over one directory, and no keychain between them:
      // the file is the whole of what a second start has to work with.
      final MemoryKeys keys = MemoryKeys();
      const AceAccount google = AceAccount(
        email: 'someone@gmail.com',
        imapHost: 'imap.gmail.com',
        imapPort: 993,
        smtpHost: 'smtp.gmail.com',
        smtpPort: 587,
        auth: MailAuth.google,
      );
      await storeOn(keys).saveAll(<StoredAccount>[
        (account: accountA, password: 'p'),
        (account: google, password: ''),
      ]);

      final AccountLoad loaded = await storeOn(keys).loadAll();

      expect(loaded.accounts.length, 2);
      expect(loaded.accounts.last.account.isGoogle, isTrue);
      expect(loaded.accounts.last.password, isEmpty);
    });

    test('the active account rides in the same record', () async {
      final MemoryKeys keys = MemoryKeys();
      await storeOn(keys).saveAll(<StoredAccount>[
        (account: accountA, password: 'p'),
      ]);
      await storeOn(keys).saveActiveEmail(accountA.email);

      expect(await storeOn(keys).loadActiveEmail(), accountA.email);

      // Saving the accounts again must not lose which one was in front.
      await storeOn(keys).saveAll(<StoredAccount>[
        (account: accountA, password: 'p'),
      ]);
      expect(await storeOn(keys).loadActiveEmail(), accountA.email);
    });

    test('clear takes the record and the key with it', () async {
      final MemoryKeys keys = MemoryKeys();
      await storeOn(keys).saveAll(<StoredAccount>[
        (account: accountA, password: 'p'),
      ]);
      expect(recordFile().existsSync(), isTrue);

      expect(await storeOn(keys).clear(), isNull);

      expect(recordFile().existsSync(), isFalse);
      expect(keys.values, isEmpty, reason: 'a key to nothing is still a key');
      expect((await storeOn(keys).loadAll()).accounts, isEmpty);
    });

    test('a tampered record is reported, not read as no accounts', () async {
      final MemoryKeys keys = MemoryKeys();
      await storeOn(keys).saveAll(<StoredAccount>[
        (account: accountA, password: 'p'),
      ]);

      final List<int> bytes = recordFile().readAsBytesSync();
      bytes[bytes.length - 1] ^= 0xFF;
      recordFile().writeAsBytesSync(bytes);

      final AccountLoad loaded = await storeOn(keys).loadAll();

      expect(loaded.accounts, isEmpty);
      expect(loaded.error, isNotNull);
    });
  });

  group('the key', () {
    test('is written to the keychain and to a file beside the record',
        () async {
      final MemoryKeys keychain = MemoryKeys();
      final DeviceKeyStore store = DeviceKeyStore(
        directory: directory,
        keychain: keychain,
      );

      await store.write('ace.credentials.key.1', 'the-key');

      expect(keychain.values['ace.credentials.key.1'], 'the-key');
      expect(
        File('${directory.path}/ace.credentials.key.1.key').existsSync(),
        isTrue,
      );
    });

    test('survives a keychain that will not answer', () async {
      final MemoryKeys live = MemoryKeys();
      final DeviceKeyStore first = DeviceKeyStore(
        directory: directory,
        keychain: live,
      );
      await first.write('ace.credentials.key.1', 'the-key');

      // The same device, next start, with the secret service not running.
      final DeviceKeyStore second = DeviceKeyStore(
        directory: directory,
        keychain: MemoryKeys(refuse: true),
      );

      expect(await second.read('ace.credentials.key.1'), 'the-key');
    });

    test('a vault opens its records through a dead keychain', () async {
      final DeviceKeyStore first = DeviceKeyStore(
        directory: directory,
        keychain: MemoryKeys(),
      );
      final AceVault sealing = AceVault(keys: first, namespace: 'ace.test');
      final Uint8List sealed = await sealing.seal(
        Uint8List.fromList(utf8.encode('a password')),
      );

      final AceVault opening = AceVault(
        keys: DeviceKeyStore(
          directory: directory,
          keychain: MemoryKeys(refuse: true),
        ),
        namespace: 'ace.test',
      );

      expect(utf8.decode(await opening.open(sealed)), 'a password');
    });
  });

  group('the layout this replaced', () {
    /// What the old store wrote: a manifest, one keychain entry per password,
    /// and the active account.
    MemoryKeys legacyKeychain() {
      final MemoryKeys legacy = MemoryKeys();
      legacy.values['ace.accounts'] = jsonEncode(<String, Object?>{
        'version': 1,
        'accounts': <Object?>[accountA.toJson()],
      });
      legacy.values['ace.password.${accountA.email}'] = 'old-secret';
      legacy.values['ace.active'] = accountA.email;
      return legacy;
    }

    test('is moved into the file, so an update does not sign anyone out',
        () async {
      final MemoryKeys keys = MemoryKeys();
      final MemoryKeys legacy = legacyKeychain();

      final AccountLoad first = await storeOn(keys, legacy: legacy).loadAll();

      expect(first.error, isNull);
      expect(first.accounts.single.password, 'old-secret');
      expect(recordFile().existsSync(), isTrue);
      expect(await storeOn(keys).loadActiveEmail(), accountA.email);

      // And the next start does not need the keychain at all.
      final AccountLoad second = await storeOn(
        keys,
        legacy: MemoryKeys(refuse: true),
      ).loadAll();

      expect(second.accounts.single.password, 'old-secret');
    });

    test('is dropped once the file holds it', () async {
      final MemoryKeys legacy = legacyKeychain();
      await storeOn(MemoryKeys(), legacy: legacy).loadAll();

      expect(legacy.values, isEmpty);
    });

    test('a keychain that will not read says so instead of starting empty',
        () async {
      final AccountLoad loaded = await storeOn(
        MemoryKeys(),
        legacy: MemoryKeys(refuse: true),
      ).loadAll();

      expect(loaded.accounts, isEmpty);
      expect(loaded.error, isNotNull);
    });
  });
}
