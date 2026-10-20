import 'dart:async';
import 'dart:io';

import 'package:ace_mail/models/ace_account.dart';
import 'package:ace_mail/models/full_message.dart';
import 'package:ace_mail/models/mail_folder.dart';
import 'package:ace_mail/models/message_summary.dart';
import 'package:ace_mail/services/mail_transport.dart';

/// A mail server that exists only in memory, so the session and controller can
/// be exercised without a network.
class FakeTransport implements MailTransport {
  FakeTransport({this.failConnect = false, this.trash = true});

  final bool failConnect;

  /// Whether this account has a Trash folder.
  final bool trash;

  final List<int> uids = <int>[];
  final Set<int> unread = <int>{};
  final Set<int> flagged = <int>{};
  final List<String> sentBodies = <String>[];

  /// Per-folder gates. When a folder has one, listing it waits on it — that is
  /// how a test decides the order two in-flight requests finish in.
  final Map<String, Completer<void>> gates = <String, Completer<void>>{};

  /// When set, `connect` waits on it, so a test can dispose mid-connection.
  Completer<void>? connectGate;

  int connects = 0;
  int pageFetches = 0;
  int searches = 0;
  bool disconnected = false;
  bool deletedPermanently = false;
  String? lastSearch;
  String? lastInReplyTo;
  String? lastReferences;
  String? lastSentPath;
  int? markedSeen;

  MailFolder get inbox => const MailFolder(
        name: 'Inbox',
        path: 'INBOX',
        role: FolderRole.inbox,
        unseen: 0,
      );

  MailFolder get archive => const MailFolder(
        name: 'Archive',
        path: 'Archive',
        role: FolderRole.folder,
        unseen: 0,
      );

  MailFolder get trashFolder => const MailFolder(
        name: 'Trash',
        path: 'Trash',
        role: FolderRole.trash,
        unseen: 0,
      );

  MailFolder get sentFolder => const MailFolder(
        name: 'Sent',
        path: 'Sent',
        role: FolderRole.sent,
        unseen: 0,
      );

  Completer<void> gateFor(String path) =>
      gates.putIfAbsent(path, () => Completer<void>());

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
    final Completer<void>? gate = connectGate;
    if (gate != null) await gate.future;
    if (failConnect) throw Exception('connection refused');
    return <MailFolder>[
      inbox,
      if (trash) trashFolder,
      sentFolder,
      archive,
    ];
  }

  @override
  Future<List<MailFolder>> listFolders() async => connect('');

  @override
  Future<void> selectFolder(MailFolder folder) async {}

  @override
  Future<List<int>> listMessageUids(MailFolder folder) async {
    final Completer<void>? gate = gates[folder.path];
    if (gate != null) await gate.future;
    return List<int>.of(uids);
  }

  @override
  Future<List<MessageSummary>> fetchSummariesByUid(
    MailFolder folder,
    List<int> ids,
  ) async {
    final Completer<void>? gate = gates[folder.path];
    if (gate != null) await gate.future;
    pageFetches++;
    return ids.map(summaryFor).toList();
  }

  @override
  Future<List<MessageSummary>> search(MailFolder folder, String query) async {
    searches++;
    lastSearch = query;
    return uids
        .where((int uid) => 'Subject $uid'.contains(query))
        .map(summaryFor)
        .toList();
  }

  @override
  Future<FullMessage> fetchMessage(MessageSummary summary) async =>
      FullMessage(
        uid: summary.uid,
        subject: summary.subject,
        fromName: summary.fromName,
        fromEmail: summary.fromEmail,
        toLine: 'Someone',
        ccLine: '',
        toEmails: 'other@example.com',
        ccEmails: '',
        date: summary.date,
        textBody: 'body of ${summary.uid}',
        htmlBody: null,
        attachments: const <MailAttachment>[],
        messageId: '<$summary.uid@example.com>',
        references: null,
      );

  @override
  Future<void> markSeen(MessageSummary summary) async {
    markedSeen = summary.uid;
    unread.remove(summary.uid);
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
  Future<void> deleteMessage(
    MessageSummary summary, {
    String? trashPath,
    bool permanently = false,
  }) async {
    // Mirrors the real service: no Trash and no explicit permanent delete is an
    // error, not a silent hard delete.
    if (!permanently && trashPath == null) {
      throw Exception('This account has no Trash folder.');
    }
    deletedPermanently = permanently;
    uids.remove(summary.uid);
  }

  @override
  Future<void> send({
    required String to,
    required String body,
    String cc = '',
    String subject = '',
    required String password,
    List<File> attachments = const <File>[],
    String? inReplyTo,
    String? references,
    String? sentPath,
  }) async {
    sentBodies.add(body);
    lastInReplyTo = inReplyTo;
    lastReferences = references;
    lastSentPath = sentPath;
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

/// A provider that files its own sent copy, so Ace Mail must not add a second.
const AceAccount gmailAccount = AceAccount(
  email: 'someone@gmail.com',
  imapHost: 'imap.gmail.com',
  imapPort: 993,
  smtpHost: 'smtp.gmail.com',
  smtpPort: 587,
);

List<int> uidRange(int count) => List<int>.generate(count, (int i) => i + 1);
