import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:ace_mail/data/vault.dart';
import 'package:flutter_test/flutter_test.dart';

/// A keychain that is not instant, because the race needs the gap.
class _MemoryKeyStore implements KeyStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async {
    await Future<void>.delayed(Duration.zero);
    return _values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    await Future<void>.delayed(Duration.zero);
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

void main() {
  test('two first writes at once cannot both mint version one', () async {
    // Both start before either finishes. Before the guard, both found an empty
    // vault, both minted version 1, and the second replaced the key the first
    // had already sealed with — so the first record could never be opened.
    final AceVault vault = AceVault(keys: _MemoryKeyStore(), random: Random(7));

    final List<Uint8List> sealed = await Future.wait(<Future<Uint8List>>[
      vault.seal(Uint8List.fromList(utf8.encode('first'))),
      vault.seal(Uint8List.fromList(utf8.encode('second'))),
    ]);

    expect(utf8.decode(await vault.open(sealed[0])), 'first');
    expect(utf8.decode(await vault.open(sealed[1])), 'second');
  });

  test('a vault that already has a key is left alone', () async {
    final AceVault vault = AceVault(keys: _MemoryKeyStore(), random: Random(7));
    final Uint8List first = await vault.seal(Uint8List.fromList(<int>[1]));

    final List<Uint8List> more = await Future.wait(<Future<Uint8List>>[
      for (int i = 0; i < 6; i++)
        vault.seal(Uint8List.fromList(<int>[i, i, i])),
    ]);

    expect(await vault.open(first), <int>[1]);
    for (int i = 0; i < more.length; i++) {
      expect(await vault.open(more[i]), <int>[i, i, i]);
    }
    // One version throughout: nothing was minted after the first.
    expect(await vault.currentVersion(), 1);
  });
}
