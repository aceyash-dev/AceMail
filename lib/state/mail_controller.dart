import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/account_store.dart';
import '../data/local_store.dart';
import '../data/preferences.dart';
import '../models/ace_account.dart';
import '../models/full_message.dart';
import '../models/mail_folder.dart';
import '../models/message_sort.dart';
import '../models/message_summary.dart';
import '../services/mail_errors.dart';
import '../services/mail_service.dart';
import '../services/mail_transport.dart';
import '../util/addresses.dart';
import 'mail_session.dart';

/// Builds the transport for an account. Tests inject a fake here.
typedef MailTransportFactory = MailTransport Function(
  AceAccount account,
  String password,
);

enum MailStatus { signedOut, connecting, ready, failed }

/// Owns every signed-in account and which one is in front.
///
/// The screens read the active account through the proxy getters below, so
/// switching accounts is just a change of index — no screen needs to know how
/// many accounts there are.
class MailController extends ChangeNotifier {
  MailController({
    AccountStore? store,
    MailTransportFactory? transportFactory,
    Preferences? preferences,
    LocalStore? localStore,
  })  : _store = store ?? AccountStore(),
        _transportFactory = transportFactory,
        _preferences = preferences,
        _localStore = localStore;

  final AccountStore _store;

  /// Injectable so tests can drive the session without a mail server.
  final MailTransportFactory? _transportFactory;

  /// Held by the sessions, which read the reading settings live.
  final Preferences? _preferences;

  /// Handed to every session, so a message read in any account is kept in the
  /// one encrypted store.
  final LocalStore? _localStore;

  /// How many cached records there are. Cheap: a directory listing.
  int get cacheEntries => _localStore?.entries ?? 0;

  /// How many bytes they take. Not cheap — it stats every file — so it is read
  /// when a screen asks, never during a build.
  int get cacheBytes => _localStore?.bytes ?? 0;

  /// Empties the local cache, keeping the keys. Nothing here is the only copy
  /// of anything: bodies and drafts are all still on the server.
  Future<void> clearCache() async => _localStore?.clear();

  final List<MailSession> _sessions = <MailSession>[];
  int _activeIndex = 0;

  /// Serialises account mutations. Signing in, removing and signing out all
  /// rewrite the same list, so letting two of them interleave produces a
  /// session list and a keychain that disagree.
  Future<void> _mutations = Future<void>.value();

  bool _disposed = false;

  /// The most recent address, used to prefill the sign-in form.
  String? lastEmail;

  MailStatus status = MailStatus.signedOut;
  String? errorMessage;
  bool connecting = false;

  List<MailSession> get sessions => List<MailSession>.unmodifiable(_sessions);

  /// The address each signed-in account sends from, in rail order.
  List<String> get accountEmails =>
      <String>[for (final MailSession s in _sessions) s.account.email];

  /// The account a message should go out from.
  ///
  /// [fromEmail] picks one of the signed-in accounts; without it, the one in
  /// front. A message sent from the wrong address is the kind of mistake you
  /// only notice when the reply comes back, so the choice is explicit.
  MailSession? _sessionFor(String? fromEmail) {
    if (fromEmail == null || fromEmail.isEmpty) return active;
    for (final MailSession session in _sessions) {
      if (session.account.email.toLowerCase() == fromEmail.toLowerCase()) {
        return session;
      }
    }
    return active;
  }
  int get activeIndex => _activeIndex;
  MailSession? get active =>
      _sessions.isEmpty ? null : _sessions[_activeIndex];
  bool get isSignedIn => _sessions.isNotEmpty;

  /// Set when the app is opened without connecting anything. There is no mail
  /// to show, but there is an app to look at, and a sign-in screen that cannot
  /// be dismissed is a wall.
  bool exploring = false;

  void startExploring() {
    exploring = true;
    notifyListeners();
  }

  void stopExploring() {
    if (!exploring) return;
    exploring = false;
    notifyListeners();
  }
  AceAccount? get account => active?.account;
  int get accountCount => _sessions.length;

  // --- proxies onto the active session -----------------------------------
  List<MailFolder> get folders => active?.folders ?? const <MailFolder>[];

  /// The rail's folders: the standard six for every account, with the server's
  /// own folders standing in for the roles it has. See [MailSession.railFolders].
  List<MailFolder> get railFolders =>
      active?.railFolders ?? kStandardFolders;
  MailFolder? get selectedFolder => active?.selectedFolder;
  List<MessageSummary> get messages =>
      active?.messages ?? const <MessageSummary>[];

  /// What the list renders: the page, filtered and sorted.
  List<MessageSummary> get visibleMessages =>
      active?.visibleMessages ?? const <MessageSummary>[];

  /// The account holder's own name, when the provider knows it. Null is
  /// ordinary: the greeting is written to read well without one.
  String? get displayName => active?.displayName;

  /// Whether the body is showing the address book rather than the mail.
  ///
  /// Here rather than in the screen because two things switch it — the floating
  /// bar on a phone, the rail on a wide window — and a tab with two switches
  /// has to have one state.
  bool contactsTab = false;

  void showContacts(bool contacts) {
    if (contactsTab == contacts) return;
    contactsTab = contacts;
    _notify();
  }

  /// Whether the active account needs Google's consent again — the grant was
  /// withdrawn, or it never covered this scope. The screen offers the sign-in
  /// rather than an error nobody can act on.
  bool get needsGoogleSignIn => active?.needsGoogleSignIn ?? false;

  bool get selecting => active?.selecting ?? false;
  int get selectedCount => active?.selected.length ?? 0;
  bool isSelected(int uid) => active?.isSelected(uid) ?? false;
  void toggleSelect(int uid) => active?.toggleSelect(uid);
  void clearSelection() => active?.clearSelection();
  Future<void> forEachSelected(
    Future<void> Function(MessageSummary message) action,
  ) async =>
      active?.forEachSelected(action);

  MessageFilter get filter => active?.filter ?? MessageFilter.all;
  MessageSort get sort => active?.sort ?? MessageSort.newest;
  MessageSummary? get openSummary => active?.openSummary;
  FullMessage? get openMessage => active?.openMessage;
  bool get loadingMessages => active?.loadingMessages ?? false;

  /// Whether the folder on screen is the trash. The actions change there:
  /// a message in the trash is restored or destroyed, not archived or deleted.
  bool get inTrash => active?.inTrash ?? false;

  /// Named for the message, because `restore` on this class already means
  /// restoring the signed-in accounts from storage.
  Future<void> restoreMessage(MessageSummary message) async =>
      active?.restore(message);

  Future<void> emptyTrash() async => active?.emptyTrash();

  /// The folder the user is looking at, for an undo to put a message back into.
  String? get currentFolderPath => active?.selectedFolder?.path;

  Future<void> undoDelete(MessageSummary message, String path) async =>
      active?.undoDelete(message, path);
  bool get refreshing => active?.refreshing ?? false;
  bool get loadingMessage => active?.loadingMessage ?? false;
  bool get loadingMore => active?.loadingMore ?? false;
  bool get hasMore => active?.hasMore ?? false;
  String? get searchQuery => active?.searchQuery;
  bool get canDeleteSafely => active?.canDeleteSafely ?? false;

  /// Whether the active account has finished connecting and loading.
  bool get isReady => active?.isReady ?? false;

  /// The active account's most recent error, if any. Surfaced as a snack bar
  /// so failures do not disappear silently.
  String? get sessionError => active?.errorMessage;

  Future<void> restore() async {
    final AccountLoad loaded = await _store.loadAll();

    if (loaded.accounts.isNotEmpty) {
      for (final StoredAccount stored in loaded.accounts) {
        _attach(_newSession(stored.account, stored.password));
      }

      // Land back on whichever account was in front last time.
      final String? previous = await _store.loadActiveEmail();
      final int index = previous == null
          ? 0
          : _sessions.indexWhere(
              (MailSession s) =>
                  MailAccountsMatch.same(s.account.email, previous),
            );
      _activeIndex = index < 0 ? 0 : index;
      lastEmail = _sessions[_activeIndex].account.email;
      status = MailStatus.ready;
    }

    // A keychain that could not be read is worth saying out loud.
    if (loaded.error != null) errorMessage = loaded.error;

    _notify();

    // Bring up only the active account. The rest connect the first time they
    // are switched to, so ten accounts do not mean ten IMAP connections.
    if (_sessions.isNotEmpty) unawaited(_sessions[_activeIndex].connect());
  }

  /// Adds an account and brings it to the front.
  Future<bool> signIn(
    AceAccount candidate,
    String password, {
    bool remember = true,
  }) =>
      _serialize(() async {
        connecting = true;
        errorMessage = null;
        exploring = false;
        status = MailStatus.connecting;
        _notify();

        final MailSession session = _newSession(candidate, password);
        final bool ok = await session.connect();
        if (_disposed) {
          session.dispose();
          return false;
        }

        connecting = false;
        if (!ok) {
          errorMessage = session.errorMessage;
          status = _sessions.isEmpty ? MailStatus.failed : MailStatus.ready;
          session.dispose();
          _notify();
          return false;
        }

        // Replace an existing session for the same address rather than
        // duplicating it. Addresses are compared case-insensitively.
        final int existing = _sessions.indexWhere(
          (MailSession s) =>
              MailAccountsMatch.same(s.account.email, candidate.email),
        );
        if (existing != -1) _detachAt(existing);

        _attach(session);
        _activeIndex = _sessions.length - 1;
        lastEmail = candidate.email;
        status = MailStatus.ready;

        if (remember) {
          final String? failure = await _persist();
          if (failure != null) errorMessage = failure;
        }
        _notify();
        return true;
      });

  void switchTo(int index) {
    if (index < 0 || index >= _sessions.length || index == _activeIndex) return;
    _activeIndex = index;
    lastEmail = _sessions[index].account.email;
    unawaited(_store.saveActiveEmail(lastEmail));
    _notify();
    // connect() is idempotent, so this is a no-op once the account is up.
    unawaited(_sessions[index].connect());
  }

  Future<void> removeAccount(int index) => _serialize(() async {
        if (index < 0 || index >= _sessions.length) return;

        final bool wasActive = index == _activeIndex;
        _detachAt(index);

        if (_sessions.isEmpty) {
          _activeIndex = 0;
          status = MailStatus.signedOut;
          final String? failure = await _store.clear();
          if (failure != null) errorMessage = failure;
        } else {
          if (index < _activeIndex) {
            // Everything above the removed account shifted down by one, so the
            // account that was in front is still in front. Clamping here would
            // silently switch the mailbox to a different account.
            _activeIndex -= 1;
          } else if (wasActive) {
            // The account in front was the one removed; fall back to whichever
            // now occupies that position, or the one before it at the end.
            _activeIndex = _activeIndex.clamp(0, _sessions.length - 1);
          }
          final String? failure = await _persist();
          if (failure != null) errorMessage = failure;
        }
        _notify();
      });

  Future<void> signOut() => _serialize(() async {
        for (final MailSession session in List<MailSession>.of(_sessions)) {
          session.removeListener(_notify);
          session.dispose();
        }
        _sessions.clear();
        _activeIndex = 0;
        lastEmail = null;
        status = MailStatus.signedOut;
        final String? failure = await _store.clear();
        if (failure != null) errorMessage = failure;
        _notify();
      });

  // --- actions, forwarded to the active session --------------------------
  Future<void> openFolder(MailFolder folder) async =>
      active?.openFolder(folder);

  Future<void> refreshMessages() async => active?.refreshMessages();

  /// Refreshes **every** signed-in account, not just the one in front.
  ///
  /// A pull is "get me up to date", and an account sitting behind a tab is still
  /// an account whose unread counts and new mail are stale. The accounts refresh
  /// together — they are separate connections, so one slow server does not hold
  /// up the others.
  Future<void> refreshAll() async {
    await Future.wait<void>(<Future<void>>[
      for (final MailSession session in _sessions) session.refresh(),
    ]);
  }

  /// Connects the active account, if it is not connected.
  ///
  /// Separate from refreshing, which needs a folder and a live connection: this
  /// is the one that gets a mailbox back after a sign-in or a dropped session.
  /// `connect()` is idempotent, so calling it when all is well does nothing.
  Future<void> reconnect() async {
    final MailSession? session = active;
    if (session == null) return;
    await session.connect();
    _notify();
  }

  Future<void> loadMore() async => active?.loadMore();

  Future<void> search(String query) async => active?.search(query);

  void clearSearch() => active?.clearSearch();

  void setFilter(MessageFilter value) => active?.setFilter(value);

  Future<void> open(MessageSummary summary) async => active?.open(summary);

  void closeMessage() => active?.closeMessage();

  Future<void> deleteOpenMessage({bool permanently = false}) async =>
      active?.deleteOpenMessage(permanently: permanently);

  Future<void> delete(MessageSummary summary, {bool permanently = false}) async =>
      active?.delete(summary, permanently: permanently);

  Future<void> archive(MessageSummary summary) async =>
      active?.archive(summary);

  Future<void> toggleRead(MessageSummary summary) async =>
      active?.toggleRead(summary);

  Future<void> markRead(MessageSummary summary) async =>
      active?.markRead(summary);

  Future<void> toggleFlag(MessageSummary summary) async =>
      active?.toggleFlag(summary);

  Future<void> markOpenUnread() async => active?.markOpenUnread();

  Future<void> toggleOpenFlagged() async => active?.toggleOpenFlagged();

  Future<void> send({
    required String to,
    required String body,
    String cc = '',
    String bcc = '',
    String subject = '',
    List<File> attachments = const <File>[],
    String? inReplyTo,
    String? references,
    String? fromEmail,
  }) async {
    final MailSession? session = _sessionFor(fromEmail);
    if (session == null) throw const MailConnectionException('Not signed in.');
    await session.send(
      to: to,
      body: body,
      cc: cc,
      bcc: bcc,
      subject: subject,
      attachments: attachments,
      inReplyTo: inReplyTo,
      references: references,
    );
  }

  void clearError() => errorMessage = null;

  MailSession _newSession(AceAccount account, String password) => MailSession(
        account: account,
        password: password,
        transport: _transportFactory?.call(account, password),
        preferences: _preferences,
        store: _localStore,
      );

  void _attach(MailSession session) {
    session.addListener(_notify);
    _sessions.add(session);
  }

  void _detachAt(int index) {
    final MailSession session = _sessions.removeAt(index);
    session.removeListener(_notify);
    session.dispose();
  }

  Future<String?> _persist() async {
    final String? failure = await _store.saveAll(
      _sessions
          .map((MailSession s) => (account: s.account, password: s.password))
          .toList(),
    );
    if (failure == null) await _store.saveActiveEmail(lastEmail);
    return failure;
  }

  /// Runs account mutations one at a time, in order.
  Future<T> _serialize<T>(Future<T> Function() action) {
    final Completer<T> result = Completer<T>();
    _mutations = _mutations.then((_) async {
      try {
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final MailSession session in _sessions) {
      session.removeListener(_notify);
      session.dispose();
    }
    _sessions.clear();
    super.dispose();
  }
}

/// Address identity for account comparison. The local part of an address is
/// technically case-sensitive, but every provider people use treats it as not,
/// and comparing raw strings produced duplicate entries for the same mailbox.
abstract final class MailAccountsMatch {
  static bool same(String a, String b) =>
      MailAddresses.normalize(a) == MailAddresses.normalize(b);
}
