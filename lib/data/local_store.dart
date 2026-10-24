import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'local_cache.dart';
import 'vault.dart';

/// Everything Ace Mail keeps on the device, in one place.
///
/// Two things live here: the draft you are part-way through writing, and the
/// messages you have already read. Both are sealed by [AceVault] before they
/// touch the disk — AES-256-GCM, a fresh nonce per record, and a key that never
/// leaves the keychain — and both can be destroyed in one step. A cache you
/// cannot clear is a cache you have to trust.
class LocalStore {
  LocalStore({required LocalCache cache, required AceVault vault})
      : _cache = cache,
        _vault = vault;

  static const String _drafts = 'drafts';
  static const String _bodies = 'bodies';
  static const String _lists = 'lists';
  static const String _folders = 'folders';
  static const String _draftKey = 'current';

  final LocalCache _cache;

  final AceVault _vault;

  /// Opens the store under the app's own directory.
  ///
  /// The directory is the app's support folder rather than a shared one: it is
  /// the app's own private space, and it is removed when the app is uninstalled
  /// — which is the behaviour a cache should have.
  static Future<LocalStore> open() async {
    final Directory directory = Directory(
      '${(await getApplicationSupportDirectory()).path}/cache',
    );
    final AceVault vault = AceVault();
    return LocalStore(
      cache: LocalCache(directory: directory, vault: vault),
      vault: vault,
    );
  }

  // --- the draft in progress ----------------------------------------------

  Future<void> saveDraft(Map<String, Object?> draft) =>
      _cache.put(_drafts, _draftKey, draft);

  Future<Map<String, Object?>?> loadDraft() => _cache.get(_drafts, _draftKey);

  Future<void> clearDraft() => _cache.remove(_drafts, _draftKey);

  // --- messages already read ----------------------------------------------

  Future<void> saveMessage(String folder, int uid, Map<String, Object?> message) =>
      _cache.put(_bodies, '$folder\u0000$uid', message);

  Future<Map<String, Object?>?> message(String folder, int uid) =>
      _cache.get(_bodies, '$folder\u0000$uid');

  // --- the message list of a folder ---------------------------------------

  /// The last page of a folder, so it appears the instant it is opened — and
  /// stays openable when the server cannot be reached at all.
  ///
  /// The UIDVALIDITY is kept beside the rows for the same reason the in-memory
  /// cache keeps it: a page from a mailbox the server has since renumbered is
  /// not the same page, and showing it would point rows at the wrong mail.
  Future<void> saveList(
    String folder,
    int? uidValidity,
    List<Map<String, Object?>> messages,
  ) =>
      _cache.put(_lists, folder, <String, Object?>{
        'uidValidity': uidValidity,
        'at': DateTime.now().millisecondsSinceEpoch,
        'messages': messages,
      });

  Future<({int? uidValidity, List<Map<String, Object?>> messages})?> loadList(
    String folder,
  ) async {
    final Map<String, Object?>? record = await _cache.get(_lists, folder);
    if (record == null) return null;
    final Object? rows = record['messages'];
    if (rows is! List) return null;
    return (
      uidValidity: record['uidValidity'] as int?,
      messages: <Map<String, Object?>>[
        for (final Object? row in rows)
          if (row is Map) row.cast<String, Object?>(),
      ],
    );
  }

  Future<void> dropList(String folder) => _cache.remove(_lists, folder);

  // --- the folder list of an account --------------------------------------

  /// The folders an account had last time it was connected.
  ///
  /// Restored before the first connection, so the rail is the real one from the
  /// first frame — and so the app opens onto a usable mailbox when there is no
  /// network to connect to.
  Future<void> saveFolders(
    String email,
    List<Map<String, Object?>> folders,
  ) =>
      _cache.put(_folders, email.toLowerCase(), <String, Object?>{
        'at': DateTime.now().millisecondsSinceEpoch,
        'folders': folders,
      });

  Future<List<Map<String, Object?>>> loadFolders(String email) async {
    final Map<String, Object?>? record =
        await _cache.get(_folders, email.toLowerCase());
    final Object? rows = record?['folders'];
    if (rows is! List) return const <Map<String, Object?>>[];
    return <Map<String, Object?>>[
      for (final Object? row in rows)
        if (row is Map) row.cast<String, Object?>(),
    ];
  }

  // --- what it costs, and how to stop paying ------------------------------

  int get entries => _cache.count();

  int get bytes => _cache.bytes();

  /// Drops every record **and the keys that open them**. Deleting the files and
  /// leaving the key behind would leave data that is still readable by anyone
  /// who finds it, which is not what "clear" is supposed to mean.
  Future<void> clear() async {
    await _cache.clear();
    await _vault.clear();
  }
}
