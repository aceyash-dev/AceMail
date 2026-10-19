import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/account_store.dart';
import '../models/ace_account.dart';
import '../models/full_message.dart';
import '../models/mail_folder.dart';
import '../models/message_summary.dart';
import '../services/mail_service.dart';

enum MailStatus { signedOut, connecting, ready, failed }

/// Owns the session: the connection, the folder list, the current message and
/// every async transition the UI reflects.
class MailController extends ChangeNotifier {
  MailController({AccountStore? store}) : _store = store ?? AccountStore();

  final AccountStore _store;

  MailStatus status = MailStatus.signedOut;
  String? errorMessage;
  AceAccount? account;

  MailService? _service;
  String? _password;

  List<MailFolder> folders = <MailFolder>[];
  MailFolder? selectedFolder;
  List<MessageSummary> messages = <MessageSummary>[];
  MessageSummary? openSummary;
  FullMessage? openMessage;

  bool loadingMessages = false;
  bool loadingMessage = false;

  bool get isSignedIn => status == MailStatus.ready && _service != null;

  /// Reconnects on launch if credentials were saved.
  Future<void> restore() async {
    final ({AceAccount account, String password})? saved = await _store.load();
    if (saved == null) {
      _set(MailStatus.signedOut);
      return;
    }
    await signIn(saved.account, saved.password, remember: false);
  }

  Future<bool> signIn(
    AceAccount candidate,
    String password, {
    bool remember = true,
  }) async {
    status = MailStatus.connecting;
    errorMessage = null;
    notifyListeners();

    final MailService service = MailService(candidate);
    try {
      final List<MailFolder> loaded = await service.connect(password);
      _service = service;
      _password = password;
      account = candidate;
      folders = loaded;
      status = MailStatus.ready;
      if (remember) await _store.save(candidate, password);
      notifyListeners();

      final MailFolder? inbox = _firstWhereOrNull(
            loaded,
            (MailFolder f) => f.role == FolderRole.inbox,
          ) ??
          _firstWhereOrNull(loaded, (MailFolder _) => true);
      if (inbox != null) await openFolder(inbox);
      return true;
    } catch (error) {
      errorMessage = error.toString();
      status = MailStatus.failed;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _service?.disconnect();
    _service = null;
    _password = null;
    account = null;
    folders = <MailFolder>[];
    messages = <MessageSummary>[];
    selectedFolder = null;
    openMessage = null;
    openSummary = null;
    await _store.clear();
    _set(MailStatus.signedOut);
  }

  Future<void> openFolder(MailFolder folder) async {
    final MailService? service = _service;
    if (service == null) return;

    selectedFolder = folder;
    openMessage = null;
    openSummary = null;
    messages = <MessageSummary>[];
    loadingMessages = true;
    notifyListeners();

    try {
      messages = await service.fetchSummaries(folder);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      loadingMessages = false;
      notifyListeners();
    }
  }

  Future<void> refreshMessages() async {
    final MailFolder? folder = selectedFolder;
    if (folder != null) await openFolder(folder);
  }

  Future<void> open(MessageSummary summary) async {
    final MailService? service = _service;
    if (service == null) return;

    openSummary = summary;
    openMessage = null;
    loadingMessage = true;
    notifyListeners();

    try {
      openMessage = await service.fetchMessage(summary);
      final int index = messages.indexWhere(
        (MessageSummary m) => m.uid == summary.uid,
      );
      if (index != -1 && !messages[index].isSeen) {
        messages = List<MessageSummary>.of(messages)
          ..[index] = messages[index].copyWith(isSeen: true);
      }
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
    final MailService? service = _service;
    final MessageSummary? summary = openSummary;
    if (service == null || summary == null) return;

    final String? trashPath = _firstWhereOrNull(
      folders,
      (MailFolder f) => f.role == FolderRole.trash,
    )?.path;
    try {
      await service.deleteMessage(summary, trashPath: trashPath);
      messages =
          messages.where((MessageSummary m) => m.uid != summary.uid).toList();
      openMessage = null;
      openSummary = null;
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
    final MailService? service = _service;
    if (service == null) throw MailException('Not signed in.');
    await service.send(
      to: to,
      body: body,
      cc: cc,
      subject: subject,
      password: _password ?? '',
      attachments: attachments,
    );
  }

  void clearError() => errorMessage = null;

  void _set(MailStatus value) {
    status = value;
    notifyListeners();
  }

  static T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
    for (final T item in items) {
      if (test(item)) return item;
    }
    return null;
  }
}
