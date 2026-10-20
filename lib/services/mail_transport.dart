import 'dart:io';

import '../models/full_message.dart';
import '../models/mail_folder.dart';
import '../models/message_summary.dart';

/// Everything the session needs from a mail server.
///
/// `MailService` is the real implementation; tests supply a fake, which is the
/// only reason the multi-account logic is testable at all.
abstract interface class MailTransport {
  Future<List<MailFolder>> connect(String password);

  Future<List<MailFolder>> listFolders();

  Future<void> selectFolder(MailFolder folder);

  /// Every message UID in [folder], newest first.
  Future<List<int>> listMessageUids(MailFolder folder);

  Future<List<MessageSummary>> fetchSummariesByUid(
    MailFolder folder,
    List<int> uids,
  );

  Future<List<MessageSummary>> search(MailFolder folder, String query);

  Future<FullMessage> fetchMessage(MessageSummary summary);

  Future<void> deleteMessage(MessageSummary summary, {String? trashPath});

  Future<void> markUnread(MessageSummary summary);

  Future<void> setFlagged(MessageSummary summary, bool flagged);

  Future<void> send({
    required String to,
    required String body,
    String cc = '',
    String subject = '',
    required String password,
    List<File> attachments = const <File>[],
  });

  Future<void> disconnect();
}
