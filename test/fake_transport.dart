import 'dart:io';

import 'package:ace_mail/models/ace_account.dart';
import 'package:ace_mail/models/full_message.dart';
import 'package:ace_mail/models/mail_folder.dart';
import 'package:ace_mail/models/message_summary.dart';
import 'package:ace_mail/services/mail_transport.dart';

/// A mail server that exists only in memory, so the session and controller can
/// be exercised without a network.
class FakeTransport implements MailTransport {
  FakeTransport({this.failConnect = false});

  final bool failConnect;

  final List<int> uids = <int>[];
  final Set<int> unread = <int>{};
  final Set<int> flagged = <int>{};
  final List<String> sentBodies = <String>[];

  int connects = 0;
  int pageFetches = 0;
  bool disconnected = false;
  String? lastSearch;

  static const MailFolder inbox = MailFolder(
    name: 'Inbox',
    path: 'INBOX',
    role: FolderRole.inbox,
    unseen: 0,
  );

  MessageSummary summaryFor(int uid) => MessageSummary(
        uid: uid,
        sequenceId: uid,
        subject: 'Subject $uid',
        fromName: 'Sender $uid',
        fromEmail: 'sender$uid@example.com',
        date: DateTime(2026, 1, 1),
        isSeen: !unread.contains(uid),
        isFlagged: flagged.contains(uid),
      );

  @override
  Future<List<MailFolder>> connect(String password) async {
    connects++;
    if (failConnect) throw Exception('connection refused');
    return <MailFolder>[inbox];
  }

  @override
  Future<List<MailFolder>> listFolders() async => <MailFolder>[inbox];

  @override
  Future<void> selectFolder(MailFolder folder) async {}

  @override
  Future<List<int>> listMessageUids(MailFolder folder) async =>
      List<int>.of(uids);

  @override
  Future<List<MessageSummary>> fetchSummariesByUid(
    MailFolder folder,
    List<int> ids,
  ) async {
    pageFetches++;
    return ids.map(summaryFor).toList();
  }

  @override
  Future<List<MessageSummary>> search(MailFolder folder, String query) async {
    lastSearch = query;
    return uids
        .where((int uid) => 'Subject $uid'.contains(query))
        .map(summaryFor)
        .toList();
  }

  @override
  Future<FullMessage> fetchMessage(MessageSummary summary) async => FullMessage(
        uid: summary.uid,
        subject: summary.subject,
        fromName: summary.fromName,
        fromEmail: summary.fromEmail,
        toLine: '',
        ccLine: '',
        date: summary.date,
        textBody: 'body of ${summary.uid}',
        htmlBody: null,
        attachments: const <MailAttachment>[],
      );

  @override
  Future<void> deleteMessage(
    MessageSummary summary, {
    String? trashPath,
  }) async {
    uids.remove(summary.uid);
  }

  @override
  Future<void> markUnread(MessageSummary summary) async =>
      unread.add(summary.uid);

  @override
  Future<void> setFlagged(MessageSummary summary, bool value) async {
    if (value) {
      flagged.add(summary.uid);
    } else {
      flagged.remove(summary.uid);
    }
  }

  @override
  Future<void> send({
    required String to,
    required String body,
    String cc = '',
    String subject = '',
    required String password,
    List<File> attachments = const <File>[],
  }) async {
    sentBodies.add(body);
  }

  @override
  Future<void> disconnect() async => disconnected = true;
}

const AceAccount accountA = AceAccount(
  email: 'a@example.com',
  imapHost: 'imap.example.com',
  imapPort: 993,
  smtpHost: 'smtp.example.com',
  smtpPort: 587,
);

const AceAccount accountB = AceAccount(
  email: 'b@example.com',
  imapHost: 'imap.example.com',
  imapPort: 993,
  smtpHost: 'smtp.example.com',
  smtpPort: 587,
);
