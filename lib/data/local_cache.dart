import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'vault.dart';

/// The encrypted store on disk.
///
/// One file per record, and the file name is a **hash** of the record's key:
/// a folder of files called `inbox-42.bin` would say more about your mail than
/// the ciphertext does.
///
/// Bounded. Past [maxEntries] the oldest records go, because a cache that grows
/// without end is a disk-full bug with a long fuse. The count is tracked as
/// writes happen, so the common path — a draft being autosaved as you type —
/// stays a single file write and only a write that goes over the bound pays for
/// a directory listing.
class LocalCache {
  LocalCache({
    required Directory directory,
    required AceVault vault,
    this.maxEntries = 500,
  })  : _directory = directory,
        _vault = vault;

  final Directory _directory;
  final AceVault _vault;

  /// How many records to keep before the oldest are dropped.
  final int maxEntries;

  /// How many records are on disk, counted lazily and kept up to date. Null
  /// until the first write, so opening the app does not list the directory.
  int? _known;

  /// What a record is bound to. The associated data is authenticated but not
  /// stored, so a record copied to another key will not open — which is what
  /// stops one message's body from being served as another's.
  static String _aad(String namespace, String key) => '$namespace\u0000$key';

  File _fileFor(String namespace, String key) {
    final String digest = sha256
        .convert(utf8.encode(_aad(namespace, key)))
        .toString()
        .substring(0, 32);
    return File('${_directory.path}/$namespace.$digest.bin');
  }

  Future<void> put(
    String namespace,
    String key,
    Map<String, Object?> value,
  ) async {
    final File file = _fileFor(namespace, key);
    await file.parent.create(recursive: true);
    final Uint8List sealed = await _vault.seal(
      Uint8List.fromList(utf8.encode(jsonEncode(value))),
      aad: _aad(namespace, key),
    );
    await file.writeAsBytes(sealed, flush: true);

    _known = (_known ?? count()) + 1;
    if (_known! > maxEntries) await _trim();
  }

  /// The record, or null when there is none — including when there is one that
  /// will not open. An unreadable record is the same as an absent one: the
  /// caller fetches it again. It must never take the screen down with it.
  Future<Map<String, Object?>?> get(String namespace, String key) async {
    final File file = _fileFor(namespace, key);
    if (!await file.exists()) return null;
    try {
      final Uint8List plain = await _vault.open(
        await file.readAsBytes(),
        aad: _aad(namespace, key),
      );
      final Object? decoded = jsonDecode(utf8.decode(plain));
      return decoded is Map<String, Object?> ? decoded : null;
    } catch (_) {
      await remove(namespace, key);
      return null;
    }
  }

  Future<void> remove(String namespace, String key) async {
    final File file = _fileFor(namespace, key);
    if (await file.exists()) await file.delete();
  }

  /// Every record, gone. This is what "clear cached content" runs, and what a
  /// key rotation runs before re-sealing what it wants to keep.
  Future<void> clear() async {
    for (final File file in _files()) {
      await file.delete();
    }
    _known = 0;
  }

  /// How many records are on disk.
  int count() => _files().length;

  /// How many bytes they take, so the setting can say what it costs.
  int bytes() {
    int total = 0;
    for (final File file in _files()) {
      total += file.lengthSync();
    }
    return total;
  }

  /// Drops the oldest records once there are more than [maxEntries].
  Future<void> _trim() async {
    final List<File> files = _files();
    if (files.length <= maxEntries) return;

    final List<File> byAge = files
      ..sort(
        (File a, File b) => a.statSync().modified.compareTo(b.statSync().modified),
      );
    for (final File file in byAge.take(files.length - maxEntries)) {
      await file.delete();
    }
    _known = maxEntries;
  }

  List<File> _files() {
    if (!_directory.existsSync()) return <File>[];
    return _directory
        .listSync()
        .whereType<File>()
        .where((File file) => file.path.endsWith('.bin'))
        .toList();
  }
}
