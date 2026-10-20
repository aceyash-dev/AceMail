import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/ace_account.dart';
import '../models/full_message.dart';
import '../models/mail_folder.dart';
import '../models/message_summary.dart';
import '../services/mail_service.dart';

/// One signed-in account: its connection, its folders, its open message.
///
/// The app can hold several sessions at once and switch between them, so all
/// per-account state lives here rather than on the app-wide controller.
class MailSession extends ChangeNotifier {
  MailSession({required this.account, required this.password});

  final AceAccount account;
  final String password;

  MailService? _service;

  bool connecting = false;
  String? errorMessage;

  List<MailFolder> folders = <MailFolder>[];
  MailFolder? selectedFolder;
  List<MessageSummary> messages = <MessageSummary>[];
  MessageSummary? openSummary;
  FullMessage? openMessage;

  bool loadingMessages = false;
  bool loadingMessage = false;

  bool get isReady => _service != null;

  Future<bool> connect() async {
    if (_service != null) return true;

    connecting = true;
    errorMessage = null;
    notifyListeners();

    final MailService service = MailService(account);
    try {
      folders = await service.connect(password);
      _service = service;
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
      notifyListeners();
      return false;
    }
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
      final int index =
          messages.indexWhere((MessageSummary m) => m.uid == summary.uid);
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

    final String? trashPath =
        _firstWhereOrNull(folders, (MailFolder f) => f.role == FolderRole.trash)
            ?.path;
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
    if (service == null) throw MailException('Not connected.');
    await service.send(
      to: to,
      body: body,
      cc: cc,
      subject: subject,
      password: password,
      attachments: attachments,
    );
  }

  void clearError() => errorMessage = null;

  @override
  void dispose() {
    final MailService? service = _service;
    _service = null;
    if (service != null) unawaited(service.disconnect());
    super.dispose();
  }

  static T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
    for (final T item in items) {
      if (test(item)) return item;
    }
    return null;
  }
}
