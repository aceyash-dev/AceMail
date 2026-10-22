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
