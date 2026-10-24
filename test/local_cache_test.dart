import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ace_mail/data/local_cache.dart';
import 'package:ace_mail/data/vault.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vault_test.dart' show MemoryKeys;

/// The encrypted store: what it promises is that a record either comes back
/// exactly as it went in, or is treated as absent. Never something else.
void main() {
  late Directory dir;
  late MemoryKeys keys;
  late LocalCache cache;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ace_cache_test');
    keys = MemoryKeys();
    cache = LocalCache(
      directory: dir,
      vault: AceVault(keys: keys, random: Random(11)),
      maxEntries: 5,
    );
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  List<File> files() => dir.listSync().whereType<File>().toList();

  test('round trips a record', () async {
    await cache.put('bodies', 'inbox:42', <String, Object?>{'text': 'hello'});
    expect(
      await cache.get('bodies', 'inbox:42'),
      <String, Object?>{'text': 'hello'},
    );
  });

  test('a missing record is null, not an error', () async {
    expect(await cache.get('bodies', 'nothing'), isNull);
  });

  test('nothing readable reaches the disk', () async {
    await cache.put('bodies', 'inbox:42', <String, Object?>{
      'text': 'the body of a private message',
    });
    final String raw =
        utf8.decode(files().single.readAsBytesSync(), allowMalformed: true);
    expect(raw, isNot(contains('private')));
    expect(raw, isNot(contains('body')));
  });

  test('the file name does not name the record', () async {
    await cache.put('bodies', 'inbox:42', <String, Object?>{'text': 'x'});
    final String name = files().single.path;
    expect(name, contains('bodies.'));
    expect(name, isNot(contains('42')));
    expect(name, isNot(contains('inbox')));
  });

  test('an altered record reads as absent, and is dropped', () async {
    await cache.put('bodies', 'a', <String, Object?>{'text': 'x'});
    final File file = files().single;
    final Uint8List raw = file.readAsBytesSync();
    raw[raw.length - 1] ^= 0x01;
    file.writeAsBytesSync(raw);

    expect(await cache.get('bodies', 'a'), isNull);
    expect(cache.count(), 0, reason: 'an unreadable record is not kept');
  });

  test('a record from another vault does not open', () async {
    await cache.put('bodies', 'a', <String, Object?>{'text': 'x'});
    final Directory other = Directory.systemTemp.createTempSync('ace_other');
    addTearDown(() => other.deleteSync(recursive: true));
    final LocalCache stranger = LocalCache(
      directory: other,
      vault: AceVault(keys: MemoryKeys(), random: Random(3)),
    );

    files().single.copySync('${other.path}/bodies.copied.bin');
    expect(await stranger.get('bodies', 'copied'), isNull);
  });

  test('remove takes one record out', () async {
    await cache.put('bodies', 'a', <String, Object?>{'text': 'x'});
    await cache.remove('bodies', 'a');
    expect(await cache.get('bodies', 'a'), isNull);
    expect(cache.count(), 0);
  });

  test('the cache is bounded', () async {
    for (int i = 0; i < 40; i++) {
      await cache.put('bodies', 'k$i', <String, Object?>{'text': '$i'});
    }
    expect(cache.count(), lessThanOrEqualTo(5));
  });

  test('the newest records are the ones that survive', () async {
    for (int i = 0; i < 12; i++) {
      await cache.put('bodies', 'k$i', <String, Object?>{'text': '$i'});
    }
    expect(await cache.get('bodies', 'k11'), isNotNull);
    expect(await cache.get('bodies', 'k0'), isNull);
  });

  test('clear empties it', () async {
    await cache.put('bodies', 'a', <String, Object?>{'text': 'x'});
    await cache.clear();
    expect(cache.count(), 0);
    expect(await cache.get('bodies', 'a'), isNull);
  });

  test('bytes reports what it costs', () async {
    expect(cache.bytes(), 0);
    await cache.put('bodies', 'a', <String, Object?>{'text': 'x'});
    expect(cache.bytes(), greaterThan(0));
  });

  test('count-based trimming keeps byte accounting in sync', () async {
    final LocalCache smallCache = LocalCache(
      directory: dir,
      vault: AceVault(keys: keys, random: Random(12)),
      maxEntries: 2,
      maxBytes: 1024 * 1024,
    );

    await smallCache.put('bodies', 'first', <String, Object?>{'text': 'first'});
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await smallCache.put('bodies', 'second', <String, Object?>{'text': 'second'});
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await smallCache.put('bodies', 'third', <String, Object?>{'text': 'third'});

    final int actualBytes = files().fold<int>(
      0,
      (int total, File file) => total + file.lengthSync(),
    );
    expect(smallCache.count(), 2);
    expect(files(), hasLength(2));
    expect(smallCache.bytes(), actualBytes);
    expect(await smallCache.get('bodies', 'third'), isNotNull);
  });

  test('namespaces do not collide', () async {
    await cache.put('bodies', 'same', <String, Object?>{'kind': 'body'});
    await cache.put('drafts', 'same', <String, Object?>{'kind': 'draft'});
    expect(await cache.get('bodies', 'same'), <String, Object?>{'kind': 'body'});
    expect(await cache.get('drafts', 'same'), <String, Object?>{'kind': 'draft'});
  });
}
