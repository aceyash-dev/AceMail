import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/account_store.dart';
import '../models/ace_account.dart';
import '../models/full_message.dart';
import '../models/mail_folder.dart';
import '../models/message_summary.dart';
import '../services/mail_service.dart';
import 'mail_session.dart';

enum MailStatus { signedOut, connecting, ready, failed }

/// Owns every signed-in account and which one is in front.
///
/// The screens read the active account through the proxy getters below, so
/// switching accounts is just a change of index — no screen needs to know how
/// many accounts there are.
class MailController extends ChangeNotifier {
  MailController({AccountStore? store}) : _store = store ?? AccountStore();

  final AccountStore _store;
  final List<MailSession> _sessions = <MailSession>[];
  int _activeIndex = 0;

  /// The most recent address, used to prefill the sign-in form.
  String? lastEmail;

  /// True until the saved accounts have been read back from the keychain.
  bool restoring = true;

  MailStatus status = MailStatus.signedOut;
  String? errorMessage;
  bool connecting = false;

  List<MailSession> get sessions => List<MailSession>.unmodifiable(_sessions);
  int get activeIndex => _activeIndex;
  MailSession? get active =>
      _sessions.isEmpty ? null : _sessions[_activeIndex];
  bool get isSignedIn => _sessions.isNotEmpty;
  AceAccount? get account => active?.account;
  int get accountCount => _sessions.length;

  // --- proxies onto the active session -----------------------------------
  List<MailFolder> get folders => active?.folders ?? const <MailFolder>[];
  MailFolder? get selectedFolder => active?.selectedFolder;
  List<MessageSummary> get messages =>
      active?.messages ?? const <MessageSummary>[];
  MessageSummary? get openSummary => active?.openSummary;
  FullMessage? get openMessage => active?.openMessage;
  bool get loadingMessages => active?.loadingMessages ?? false;
  bool get loadingMessage => active?.loadingMessage ?? false;

  Future<void> restore() async {
    final List<StoredAccount> saved = await _store.loadAll();
    if (saved.isNotEmpty) {
      lastEmail = saved.last.account.email;
      for (final StoredAccount stored in saved) {
        _attach(MailSession(account: stored.account, password: stored.password));
      }
      _activeIndex = 0;
      status = MailStatus.ready;
    }
    restoring = false;
    notifyListeners();

    // Connect in the background so the UI is up immediately.
    for (final MailSession session in _sessions) {
      unawaited(session.connect());
    }
  }

  /// Adds an account and brings it to the front.
  Future<bool> signIn(
    AceAccount candidate,
    String password, {
    bool remember = true,
  }) async {
    connecting = true;
    errorMessage = null;
    status = MailStatus.connecting;
    notifyListeners();

    final MailSession session =
        MailSession(account: candidate, password: password);
    final bool ok = await session.connect();

    connecting = false;
    if (!ok) {
      errorMessage = session.errorMessage;
      status = _sessions.isEmpty ? MailStatus.failed : MailStatus.ready;
      session.dispose();
      notifyListeners();
      return false;
    }

    // Replace an existing session for the same address rather than duplicating.
    final int existing = _sessions.indexWhere(
      (MailSession s) => s.account.email == candidate.email,
    );
    if (existing != -1) {
      _detachAt(existing);
    }

    _attach(session);
    _activeIndex = _sessions.length - 1;
    lastEmail = candidate.email;
    status = MailStatus.ready;
    if (remember) await _persist();
    notifyListeners();
    return true;
  }

  void switchTo(int index) {
    if (index < 0 || index >= _sessions.length || index == _activeIndex) return;
    _activeIndex = index;
    lastEmail = _sessions[index].account.email;
    notifyListeners();
    // Connect lazily if this account has not been opened yet this run.
    final MailSession session = _sessions[index];
    if (!session.isReady && !session.connecting) {
      unawaited(session.connect());
    }
  }

  Future<void> removeAccount(int index) async {
    if (index < 0 || index >= _sessions.length) return;
    _detachAt(index);
    if (_sessions.isEmpty) {
      _activeIndex = 0;
      status = MailStatus.signedOut;
      await _store.clear();
    } else {
      _activeIndex = _activeIndex.clamp(0, _sessions.length - 1);
      await _persist();
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    for (final MailSession session in List<MailSession>.of(_sessions)) {
      session.removeListener(notifyListeners);
      session.dispose();
    }
    _sessions.clear();
    _activeIndex = 0;
    lastEmail = null;
    await _store.clear();
    status = MailStatus.signedOut;
    notifyListeners();
  }

  // --- actions, forwarded to the active session --------------------------
  Future<void> openFolder(MailFolder folder) async =>
      active?.openFolder(folder);

  Future<void> refreshMessages() async => active?.refreshMessages();

  Future<void> open(MessageSummary summary) async => active?.open(summary);

  void closeMessage() => active?.closeMessage();

  Future<void> deleteOpenMessage() async => active?.deleteOpenMessage();

  Future<void> send({
    required String to,
    required String body,
    String cc = '',
    String subject = '',
    List<File> attachments = const <File>[],
  }) async {
    final MailSession? session = active;
    if (session == null) throw MailException('Not signed in.');
    await session.send(
      to: to,
      body: body,
      cc: cc,
      subject: subject,
      attachments: attachments,
    );
  }

  void clearError() => errorMessage = null;

  void _attach(MailSession session) {
    session.addListener(notifyListeners);
    _sessions.add(session);
  }

  void _detachAt(int index) {
    final MailSession session = _sessions.removeAt(index);
    session.removeListener(notifyListeners);
    session.dispose();
  }

  Future<void> _persist() => _store.saveAll(
        _sessions
            .map((MailSession s) =>
                (account: s.account, password: s.password))
            .toList(),
      );
}
