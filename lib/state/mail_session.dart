import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/preferences.dart';
import '../models/ace_account.dart';
import '../models/full_message.dart';
import '../models/mail_folder.dart';
import '../models/message_summary.dart';
import '../services/mail_service.dart';
import '../services/mail_transport.dart';

/// One signed-in account: its connection, its folders, its open message.
///
/// The app can hold several sessions at once and switch between them, so all
/// per-account state lives here rather than on the app-wide controller.
class MailSession extends ChangeNotifier {
  MailSession({
    required this.account,
    required this.password,
    MailTransport? transport,
    Preferences? preferences,
  })  : _injected = transport,
        _preferences = preferences;

  final AceAccount account;
  final String password;
  final MailTransport? _injected;

  /// Read live, so toggling "mark as read when opened" applies to the very
  /// next message without rebuilding the session.
  final Preferences? _preferences;

  bool get _markAsRead => _preferences?.markAsReadOnOpen ?? true;

  /// The default page size, for callers with no settings to hand.
  static const int pageSize = 40;

  /// How many messages a page holds, from the user's setting.
  int get _pageSize => _preferences?.pageSize.count ?? pageSize;

  /// Providers that file a copy of what you send without being asked. Adding a
  /// second copy ourselves is how you end up with duplicates in Sent.
  static const Set<String> _filesSentItself = <String>{
    'gmail.com', 'googlemail.com',
    'outlook.com', 'hotmail.com', 'live.com', 'msn.com',
    'icloud.com', 'me.com', 'mac.com',
    'yahoo.com', 'yahoo.in', 'ymail.com',
  };

  late final MailTransport _transport = _injected ??
      MailService(
        account,
        reconnectAllowed: () => _preferences?.autoReconnect ?? true,
      );

  bool connecting = false;
  String? errorMessage;

  List<MailFolder> folders = <MailFolder>[];
  MailFolder? selectedFolder;
  List<MessageSummary> messages = <MessageSummary>[];
  MessageSummary? openSummary;
  FullMessage? openMessage;

  bool loadingMessages = false;
  bool loadingMessage = false;
  bool loadingMore = false;

  /// Every UID in the selected folder, newest first — the paging cursor.
  List<int> _uids = <int>[];

  /// The query in force, or null when the folder is simply being listed.
  String? searchQuery;

  bool _connected = false;
  bool _disposed = false;
  Future<bool>? _connecting;

  /// Request generations. Every listing carries the token it was started with,
  /// and a response is only applied if it is still the newest one — otherwise
  /// switching folders quickly lets a slow earlier request overwrite the newer
  /// selection.
  int _folderToken = 0;
  int _messageToken = 0;

  bool get isReady => _connected;

  bool get hasMore => searchQuery == null && messages.length < _uids.length;

  String? get trashPath => _folderPathFor(FolderRole.trash);

  String? get sentPath => _folderPathFor(FolderRole.sent);

  bool get canDeleteSafely => trashPath != null;

  String? _folderPathFor(FolderRole role) {
    for (final MailFolder folder in folders) {
      if (folder.role == role) return folder.path;
    }
    return null;
  }

  /// Connects at most once. A switch that arrives while the first attempt is
  /// still running joins that attempt instead of opening a second connection.
  Future<bool> connect() {
    final Future<bool>? inFlight = _connecting;
    if (inFlight != null) return inFlight;
    if (_connected) return Future<bool>.value(true);
    final Future<bool> attempt = _connect();
    _connecting = attempt;
    return attempt;
  }

  Future<bool> _connect() async {
    connecting = true;
    errorMessage = null;
    _notify();

    try {
      final List<MailFolder> loaded = await _transport.connect(password);

      // The session may have been abandoned while we were connecting; do not
      // leave a live connection behind for a screen that no longer exists.
      if (_disposed) {
        unawaited(_transport.disconnect());
        return false;
      }

      folders = loaded;
      _connected = true;
      connecting = false;
      _notify();

      final MailFolder? inbox =
          _firstWhereOrNull(folders, (MailFolder f) => f.role == FolderRole.inbox) ??
              _firstWhereOrNull(folders, (MailFolder _) => true);
      if (inbox != null) await openFolder(inbox);
      return true;
    } catch (error) {
      errorMessage = error.toString();
      connecting = false;
      _connecting = null; // let a later attempt try again
      _notify();
      return false;
    }
  }

  Future<void> openFolder(MailFolder folder) async {
    if (!_connected) return;

    final int token = ++_folderToken;
    selectedFolder = folder;
    searchQuery = null;
    openMessage = null;
    openSummary = null;
    messages = <MessageSummary>[];
    _uids = <int>[];
    loadingMessages = true;
    errorMessage = null;
    _notify();

    try {
      final List<int> uids = await _transport.listMessageUids(folder);
      final List<MessageSummary> page = await _transport.fetchSummariesByUid(
        folder,
        uids.take(_pageSize).toList(),
      );
      if (token != _folderToken) return; // a newer folder won
      _uids = uids;
      messages = page;
    } catch (error) {
      if (token != _folderToken) return;
      errorMessage = error.toString();
    } finally {
      if (token == _folderToken) {
        loadingMessages = false;
        _notify();
      }
    }
  }

  /// Pulls the next page of older messages.
  Future<void> loadMore() async {
    final MailFolder? folder = selectedFolder;
    if (!_connected || folder == null || loadingMore || !hasMore) return;

    final int token = _folderToken;
    loadingMore = true;
    _notify();
    try {
      final List<int> next =
          _uids.skip(messages.length).take(_pageSize).toList();
      final List<MessageSummary> more =
          await _transport.fetchSummariesByUid(folder, next);
      if (token != _folderToken) return;
      messages = <MessageSummary>[...messages, ...more];
    } catch (error) {
      if (token != _folderToken) return;
      errorMessage = error.toString();
    } finally {
      if (token == _folderToken) {
        loadingMore = false;
        _notify();
      }
    }
  }

  Future<void> refreshMessages() async {
    final MailFolder? folder = selectedFolder;
    if (folder == null) return;
    final String? query = searchQuery;
    if (query != null) {
      await search(query);
    } else {
      await openFolder(folder);
    }
  }

  /// Searches sender and subject. An empty query returns to the plain listing.
  Future<void> search(String query) async {
    final MailFolder? folder = selectedFolder;
    final String trimmed = query.trim();
    if (!_connected || folder == null) return;

    if (trimmed.isEmpty) {
      searchQuery = null;
      await openFolder(folder);
      return;
    }

    final int token = ++_folderToken;
    searchQuery = trimmed;
    openMessage = null;
    openSummary = null;
    messages = <MessageSummary>[];
    loadingMessages = true;
    errorMessage = null;
    _notify();

    try {
      final List<MessageSummary> found =
          await _transport.search(folder, trimmed);
      if (token != _folderToken) return;
      messages = found;
    } catch (error) {
      if (token != _folderToken) return;
      errorMessage = error.toString();
    } finally {
      if (token == _folderToken) {
        loadingMessages = false;
        _notify();
      }
    }
  }

  void clearSearch() {
    final MailFolder? folder = selectedFolder;
    searchQuery = null;
    if (folder != null) unawaited(openFolder(folder));
  }

  Future<void> open(MessageSummary summary) async {
    if (!_connected) return;

    final int token = ++_messageToken;
    openSummary = summary;
    openMessage = null;
    loadingMessage = true;
    _notify();

    try {
      final FullMessage loaded = await _transport.fetchMessage(summary);
      if (token != _messageToken) return; // a newer message won
      openMessage = loaded;
      if (_markAsRead) {
        _replace(summary.uid, summary.copyWith(isSeen: true));
        // Set \Seen deliberately rather than as a side effect of reading, so
        // the row and the server agree. Best effort: a failure must not hide
        // the mail.
        unawaited(_markSeenQuietly(summary));
      }
    } catch (error) {
      if (token != _messageToken) return;
      errorMessage = error.toString();
    } finally {
      if (token == _messageToken) {
        loadingMessage = false;
        _notify();
      }
    }
  }

  Future<void> _markSeenQuietly(MessageSummary summary) async {
    try {
      await _transport.markSeen(summary);
    } catch (_) {
      // The message is readable either way.
    }
  }

  void closeMessage() {
    _messageToken++; // anything in flight for the old message is now stale
    openMessage = null;
    openSummary = null;
    _notify();
  }

  /// Deletes any row, not just the open one, so a swipe can call it.
  Future<void> delete(MessageSummary summary, {bool permanently = false}) =>
      _runOn(
        summary,
        () => _transport.deleteMessage(
          summary,
          trashPath: trashPath,
          permanently: permanently,
        ),
        remove: true,
      );

  Future<void> deleteOpenMessage({bool permanently = false}) async {
    final MessageSummary? summary = openSummary;
    if (!_connected || summary == null) return;
    await delete(summary, permanently: permanently);
  }

  /// Moves a message out of the way. Needs an Archive folder to move it to.
  Future<void> archive(MessageSummary summary) async {
    final String? path = _folderPathFor(FolderRole.archive);
    if (path == null) {
      errorMessage = 'This account has no Archive folder.';
      _notify();
      return;
    }
    await _runOn(summary, () => _transport.moveMessage(summary, path),
        remove: true);
  }

  /// Flips a message's read state from the list.
  Future<void> toggleRead(MessageSummary summary) async {
    final bool next = !summary.isSeen;
    await _runOn(
      summary,
      () => next
          ? _transport.markSeen(summary)
          : _transport.markUnread(summary),
      updated: summary.copyWith(isSeen: next),
    );
  }

  /// Flips a message's flag from the list.
  Future<void> toggleFlag(MessageSummary summary) async {
    final bool next = !summary.isFlagged;
    await _runOn(
      summary,
      () => _transport.setFlagged(summary, next),
      updated: summary.copyWith(isFlagged: next),
    );
  }

  /// Runs an action against one row and reconciles the list with the result.
  /// Either the row leaves, or it is replaced in place — never both, and never
  /// a silent no-op.
  Future<void> _runOn(
    MessageSummary summary,
    Future<void> Function() action, {
    MessageSummary? updated,
    bool remove = false,
  }) async {
    if (!_connected) return;
    try {
      await action();
      if (remove) {
        messages =
            messages.where((MessageSummary m) => m.uid != summary.uid).toList();
        _uids = _uids.where((int uid) => uid != summary.uid).toList();
        if (openSummary?.uid == summary.uid) {
          openMessage = null;
          openSummary = null;
        }
      } else if (updated != null) {
        _replace(summary.uid, updated);
        if (openSummary?.uid == summary.uid) openSummary = updated;
      }
      _notify();
    } catch (error) {
      errorMessage = error.toString();
      _notify();
    }
  }

  /// Flips the message back to unread and leaves it open.
  Future<void> markOpenUnread() async {
    final MessageSummary? summary = openSummary;
    if (summary == null) return;
    try {
      await _transport.markUnread(summary);
      _replace(summary.uid, summary.copyWith(isSeen: false));
      _notify();
    } catch (error) {
      errorMessage = error.toString();
      _notify();
    }
  }

  Future<void> toggleOpenFlagged() async {
    final MessageSummary? summary = openSummary;
    if (summary == null) return;
    final bool next = !summary.isFlagged;
    try {
      await _transport.setFlagged(summary, next);
      _replace(summary.uid, summary.copyWith(isFlagged: next));
      openSummary = summary.copyWith(isFlagged: next);
      _notify();
    } catch (error) {
      errorMessage = error.toString();
      _notify();
    }
  }

  Future<void> send({
    required String to,
    required String body,
    String cc = '',
    String subject = '',
    List<File> attachments = const <File>[],
    String? inReplyTo,
    String? references,
  }) async {
    if (!_connected) throw const MailConnectionException('Not connected.');
    await _transport.send(
      to: to,
      body: body,
      cc: cc,
      subject: subject,
      password: password,
      attachments: attachments,
      inReplyTo: inReplyTo,
      references: references,
      // Only file a copy ourselves when the provider will not.
      sentPath: _filesSentItself.contains(account.domain) ? null : sentPath,
    );
  }

  void clearError() => errorMessage = null;

  void _replace(int uid, MessageSummary updated) {
    final int index = messages.indexWhere((MessageSummary m) => m.uid == uid);
    if (index == -1) return;
    messages = List<MessageSummary>.of(messages)..[index] = updated;
  }

  /// Never notify after disposal: listeners are gone and ChangeNotifier throws
  /// in debug builds.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _messageToken++;
    _folderToken++;
    if (_connected) unawaited(_transport.disconnect());
    _connected = false;
    super.dispose();
  }

  static T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
    for (final T item in items) {
      if (test(item)) return item;
    }
    return null;
  }
}
