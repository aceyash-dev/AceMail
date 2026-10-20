import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

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
  }) : _injected = transport;

  final AceAccount account;
  final String password;
  final MailTransport? _injected;

  /// How many messages a page holds. The list grows a page at a time.
  static const int pageSize = 40;

  late final MailTransport _transport = _injected ?? MailService(account);

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
  Future<bool>? _connecting;

  bool get isReady => _connected;

  bool get hasMore => searchQuery == null && messages.length < _uids.length;

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
    notifyListeners();

    try {
      folders = await _transport.connect(password);
      _connected = true;
      connecting = false;
      notifyListeners();

      final MailFolder? inbox =
          _firstWhereOrNull(folders, (MailFolder f) => f.role == FolderRole.inbox) ??
              _firstWhereOrNull(folders, (MailFolder _) => true);
      if (inbox != null) await openFolder(inbox);
      return true;
    } catch (error) {
      errorMessage = error.toString();
      connecting = false;
      _connecting = null; // let a later attempt try again
      notifyListeners();
      return false;
    }
  }

  Future<void> openFolder(MailFolder folder) async {
    if (!_connected) return;

    selectedFolder = folder;
    searchQuery = null;
    openMessage = null;
    openSummary = null;
    messages = <MessageSummary>[];
    _uids = <int>[];
    loadingMessages = true;
    errorMessage = null;
    notifyListeners();

    try {
      _uids = await _transport.listMessageUids(folder);
      messages = await _transport.fetchSummariesByUid(
        folder,
        _uids.take(pageSize).toList(),
      );
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      loadingMessages = false;
      notifyListeners();
    }
  }

  /// Pulls the next page of older messages.
  Future<void> loadMore() async {
    final MailFolder? folder = selectedFolder;
    if (!_connected || folder == null || loadingMore || !hasMore) return;

    loadingMore = true;
    notifyListeners();
    try {
      final List<int> next =
          _uids.skip(messages.length).take(pageSize).toList();
      final List<MessageSummary> more =
          await _transport.fetchSummariesByUid(folder, next);
      messages = <MessageSummary>[...messages, ...more];
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      loadingMore = false;
      notifyListeners();
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

  /// Searches subject, sender and recipient. An empty query returns to the
  /// plain folder listing.
  Future<void> search(String query) async {
    final MailFolder? folder = selectedFolder;
    final String trimmed = query.trim();
    if (!_connected || folder == null) return;

    if (trimmed.isEmpty) {
      searchQuery = null;
      await openFolder(folder);
      return;
    }

    searchQuery = trimmed;
    openMessage = null;
    openSummary = null;
    messages = <MessageSummary>[];
    loadingMessages = true;
    errorMessage = null;
    notifyListeners();

    try {
      messages = await _transport.search(folder, trimmed);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      loadingMessages = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    final MailFolder? folder = selectedFolder;
    searchQuery = null;
    if (folder != null) unawaited(openFolder(folder));
  }

  Future<void> open(MessageSummary summary) async {
    if (!_connected) return;

    openSummary = summary;
    openMessage = null;
    loadingMessage = true;
    notifyListeners();

    try {
      openMessage = await _transport.fetchMessage(summary);
      _replace(summary.uid, summary.copyWith(isSeen: true));
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      loadingMessage = false;
      notifyListeners();
    }
  }

  void closeMessage() {
    openMessage = null;
    openSummary = null;
    notifyListeners();
  }

  Future<void> deleteOpenMessage() async {
    final MessageSummary? summary = openSummary;
    if (!_connected || summary == null) return;

    final String? trashPath =
        _firstWhereOrNull(folders, (MailFolder f) => f.role == FolderRole.trash)
            ?.path;
    try {
      await _transport.deleteMessage(summary, trashPath: trashPath);
      messages = messages
          .where((MessageSummary m) => m.uid != summary.uid)
          .toList();
      _uids = _uids.where((int uid) => uid != summary.uid).toList();
      openMessage = null;
      openSummary = null;
      notifyListeners();
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  /// Flips the message back to unread and leaves it open.
  Future<void> markOpenUnread() async {
    final MessageSummary? summary = openSummary;
    if (summary == null) return;
    try {
      await _transport.markUnread(summary);
      _replace(summary.uid, summary.copyWith(isSeen: false));
      notifyListeners();
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
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
      notifyListeners();
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> send({
    required String to,
    required String body,
    String cc = '',
    String subject = '',
    List<File> attachments = const <File>[],
  }) async {
    if (!_connected) throw MailException('Not connected.');
    await _transport.send(
      to: to,
      body: body,
      cc: cc,
      subject: subject,
      password: password,
      attachments: attachments,
    );
  }

  void clearError() => errorMessage = null;

  void _replace(int uid, MessageSummary updated) {
    final int index = messages.indexWhere((MessageSummary m) => m.uid == uid);
    if (index == -1) return;
    messages = List<MessageSummary>.of(messages)..[index] = updated;
  }

  @override
  void dispose() {
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
