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
    this.maxEntries = 1000,
    this.maxBytes = 96 * 1024 * 1024,
  })  : _directory = directory,
        _vault = vault;

  final Directory _directory;
  final AceVault _vault;

  /// How many records to keep before the oldest are dropped.
  ///
  /// A thousand: opening a folder you have already read should not wait on the
  /// network, and a thousand bodies is roughly a month of ordinary mail. The
  /// byte bound below is what actually keeps it honest.
  final int maxEntries;

  /// The other bound. [maxEntries] alone is not a bound on anything a person
  /// would recognise: 500 cached bodies is 500 kilobytes of small mail or
  /// **one gigabyte** of large mail, and the difference is not something the
  /// count can see. Whichever limit is reached first trims.
  final int maxBytes;

  /// How many records are on disk, counted lazily and kept up to date. Null
  /// until the first write, so opening the app does not list the directory.
  int? _known;

  /// See [bytes]. Kept alongside [_known] and set together.
  int _bytes = 0;

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

    // What is being replaced, before it is replaced. A record written twice is
    // one record, and the difference in size is the only thing the total has to
    // know about it.
    if (_known == null) recount();
    final bool existed = file.existsSync();
    final int before = existed ? file.lengthSync() : 0;

    final Uint8List sealed = await _vault.seal(
      Uint8List.fromList(utf8.encode(jsonEncode(value))),
      aad: _aad(namespace, key),
    );
    await file.writeAsBytes(sealed, flush: true);

    _bytes += sealed.length - before;
    if (!existed) _known = (_known ?? 0) + 1;
    if ((_known ?? 0) > maxEntries || _bytes > maxBytes) await _trim();
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
    if (!await file.exists()) return;
    if (_known == null) recount();
    _bytes -= file.lengthSync();
    _known = ((_known ?? 1) - 1).clamp(0, 1 << 30);
    await file.delete();
  }

  /// Every record, gone. This is what "clear cached content" runs, and what a
  /// key rotation runs before re-sealing what it wants to keep.
  Future<void> clear() async {
    for (final File file in _files()) {
      await file.delete();
    }
    _known = 0;
    _bytes = 0;
  }

  /// How many records there are. Also a running total; see [bytes].
  int count() => _known ?? recount();

  /// How many bytes they take.
  ///
  /// Kept as a running total rather than measured. It used to walk the
  /// directory and stat every file, and it was called on the way out of *every
  /// write* to check the limit — so caching one message cost a stat per cached
  /// message, and the cost grew with the cache. The number is adjusted from the
  /// size of the file being replaced, which is the only thing that changes it.
  int bytes() => _bytes;

  /// Walks the directory and sets both totals from what is actually there.
  ///
  /// For startup, and for after anything that removes files without going
  /// through [remove] — the only way the running total can drift.
  int recount() {
    final List<File> files = _files();
    int total = 0;
    for (final File file in files) {
      total += file.lengthSync();
    }
    _bytes = total;
    _known = files.length;
    return total;
  }

  /// Drops the oldest records until both bounds are satisfied.
  ///
  /// Oldest first, so what goes is what has not been read in longest — which is
  /// the right guess for a mail cache, where the thing you want again is
  /// usually the thing you looked at recently.
  Future<void> _trim() async {
    final List<File> files = _files();
    if (files.isEmpty) return;

    final List<File> byAge = files
      ..sort(
        (File a, File b) => a.statSync().modified.compareTo(b.statSync().modified),
      );

    // Work out how many have to go for both bounds at once, rather than
    // trimming to the count and then finding the bytes still over.
    int total = 0;
    for (final File file in byAge) {
      total += file.lengthSync();
    }

    int keep = byAge.length;
    if (keep > maxEntries) keep = maxEntries;
    while (keep > 0 && total > maxBytes) {
      total -= byAge[byAge.length - keep].lengthSync();
      keep -= 1;
    }

    // When the entry-count limit forces eviction but the byte limit does not,
    // the byte loop above never accounts for those deleted files. Subtract
    // every eviction here so the running total matches the files that survive.
    final List<File> evicted = byAge.take(byAge.length - keep).toList();
    for (final File file in evicted) {
      total -= file.lengthSync();
      await file.delete();
    }

    // The trim already worked these out; keep them rather than walking again.
    _bytes = total;
    _known = keep;
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
