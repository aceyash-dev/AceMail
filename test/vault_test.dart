import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:ace_mail/data/vault.dart';
import 'package:flutter_test/flutter_test.dart';

/// A keychain in a map, so the vault can be tested without a plugin channel.
class MemoryKeys implements KeyStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

Uint8List bytes(String value) => Uint8List.fromList(utf8.encode(value));

void main() {
  late MemoryKeys keys;
  late AceVault vault;

  setUp(() {
    keys = MemoryKeys();
    vault = AceVault(keys: keys, random: Random(7));
  });

  group('seal and open', () {
    test('round trips', () async {
      final Uint8List sealed = await vault.seal(bytes('hello'));
      expect(utf8.decode(await vault.open(sealed)), 'hello');
    });

    test('the plaintext is not in the record', () async {
      final Uint8List sealed = await vault.seal(bytes('the body of a message'));
      expect(
        utf8.decode(sealed, allowMalformed: true),
        isNot(contains('body')),
      );
    });

    test('the record carries the format and the key version', () async {
      final Uint8List sealed = await vault.seal(bytes('x'));
      expect(sealed[0], AceVault.formatVersion);
      expect(sealed[1], 1);
      // format, version, a 12-byte nonce, and at least a 16-byte tag.
      expect(
        sealed.length,
        greaterThanOrEqualTo(2 + AceVault.nonceLength + 16),
      );
    });

    test('the same plaintext seals differently every time', () async {
      // Fresh nonces. A repeated nonce under one key is the failure GCM does
      // not survive, so this is the property worth pinning.
      final Uint8List a = await vault.seal(bytes('same'));
      final Uint8List b = await vault.seal(bytes('same'));
      expect(a, isNot(equals(b)));
      expect(utf8.decode(await vault.open(a)), 'same');
      expect(utf8.decode(await vault.open(b)), 'same');
    });

    test('a flipped byte fails to open', () async {
      final Uint8List sealed = await vault.seal(bytes('hello'));
      sealed[sealed.length - 1] ^= 0x01;
      await expectLater(vault.open(sealed), throwsA(isA<AceVaultException>()));
    });

    test('a truncated record fails to open', () async {
      final Uint8List sealed = await vault.seal(bytes('hello'));
      await expectLater(
        vault.open(Uint8List.sublistView(sealed, 0, sealed.length - 4)),
        throwsA(isA<AceVaultException>()),
      );
    });

    test('a record bound to one place does not open in another', () async {
      // The associated data is the folder and uid a body belongs to, so one
      // message's body cannot be served as another's.
      final Uint8List sealed =
          await vault.seal(bytes('hello'), aad: 'inbox\u000042');
      await expectLater(
        vault.open(sealed, aad: 'inbox\u000043'),
        throwsA(isA<AceVaultException>()),
      );
      expect(
        utf8.decode(await vault.open(sealed, aad: 'inbox\u000042')),
        'hello',
      );
    });

    test('something that is not a record is refused, not guessed at', () async {
      await expectLater(
        vault.open(bytes('not a record')),
        throwsA(isA<AceVaultException>()),
      );
    });

    test('an unknown format is refused', () async {
      final Uint8List sealed = await vault.seal(bytes('x'));
      sealed[0] = 99;
      await expectLater(vault.open(sealed), throwsA(isA<AceVaultException>()));
    });

    test('an empty plaintext round trips', () async {
      final Uint8List sealed = await vault.seal(Uint8List(0));
      expect(await vault.open(sealed), isEmpty);
    });

    test('a long plaintext round trips', () async {
      final String long = 'x' * 200000;
      final Uint8List sealed = await vault.seal(bytes(long));
      expect(utf8.decode(await vault.open(sealed)), long);
    });
  });

  group('key rotation', () {
    test('a rotation keeps older records readable', () async {
      final Uint8List before = await vault.seal(bytes('under key one'));
      expect(await vault.rotate(), 2);
      final Uint8List after = await vault.seal(bytes('under key two'));

      expect(before[1], 1);
      expect(after[1], 2);
      expect(utf8.decode(await vault.open(before)), 'under key one');
      expect(utf8.decode(await vault.open(after)), 'under key two');
    });

    test('readableVersions lists what is still openable', () async {
      await vault.seal(bytes('x'));
      await vault.rotate();
      expect(await vault.readableVersions(), <int>[1, 2]);
    });

    test('losing one key takes only its records', () async {
      final Uint8List old = await vault.seal(bytes('old'));
      await vault.rotate();
      final Uint8List fresh = await vault.seal(bytes('new'));

      keys.values.remove('ace.vault.key.1');

      await expectLater(vault.open(old), throwsA(isA<AceVaultException>()));
      expect(utf8.decode(await vault.open(fresh)), 'new');
    });

    test('clear forgets every key, and sealing mints a fresh one', () async {
      await vault.seal(bytes('x'));
      await vault.rotate();
      await vault.clear();

      expect(await vault.readableVersions(), isEmpty);
      final Uint8List sealed = await vault.seal(bytes('after'));
      expect(sealed[1], 1);
      expect(utf8.decode(await vault.open(sealed)), 'after');
    });
  });
}
