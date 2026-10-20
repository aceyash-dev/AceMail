import 'dart:io';

import 'package:enough_mail/enough_mail.dart';

import '../models/ace_account.dart';
import '../models/full_message.dart';
import '../models/mail_folder.dart';
import '../models/message_summary.dart';
import 'mail_transport.dart';

/// A failure worth showing the user, phrased for a person rather than a log.
class MailException implements Exception {
  MailException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin, explicit wrapper over `enough_mail`'s low-level IMAP and SMTP clients.
/// One instance per signed-in account; every call is sequential on the IMAP
/// client, which enough_mail serialises internally.
class MailService implements MailTransport {
  MailService(this.account);

  final AceAccount account;
  ImapClient? _imap;

  bool get isConnected => _imap != null;

  ImapClient get _client {
    final ImapClient? client = _imap;
    if (client == null) throw MailException('Not connected.');
    return client;
  }

  @override
  Future<List<MailFolder>> connect(String password) async {
    final ImapClient client = ImapClient(isLogEnabled: false);
    try {
      await client.connectToServer(
        account.imapHost,
        account.imapPort,
        isSecure: true,
      );
      await client.login(account.email, password);
    } on ImapException catch (error) {
      await _safeLogout(client);
      throw MailException(_friendlyImapError(error));
    } catch (error) {
      await _safeLogout(client);
      throw MailException('Could not reach ${account.imapHost}. $error');
    }
    _imap = client;
    return listFolders();
  }

  @override
  Future<List<MailFolder>> listFolders() async {
    final List<Mailbox> mailboxes = await _client.listMailboxes();
    return mailboxes
        // Container folders such as Gmail's "[Gmail]" cannot be selected and
        // hold no messages of their own, so they never belong in the rail.
        .where((Mailbox mailbox) => !mailbox.isNotSelectable)
        .map(MailFolder.fromMailbox)
        .toList()
      ..sort((MailFolder a, MailFolder b) {
        final int byRole = a.sortOrder.compareTo(b.sortOrder);
        return byRole != 0 ? byRole : a.name.compareTo(b.name);
      });
  }

  @override
  Future<void> selectFolder(MailFolder folder) =>
      _client.selectMailboxByPath(folder.path);

  /// Every message UID in [folder], newest first. One cheap SEARCH, so paging
  /// and searching can both work from the same list.
  @override
  Future<List<int>> listMessageUids(MailFolder folder) async {
    await selectFolder(folder);
    final SearchImapResult result = await _client.uidSearchMessages(
      searchCriteria: 'ALL',
    );
    final List<int> uids = result.matchingSequence?.toList() ?? <int>[];
    return uids.reversed.toList();
  }

  /// Headers only — the list never pulls message bodies.
  @override
  Future<List<MessageSummary>> fetchSummariesByUid(
    MailFolder folder,
    List<int> uids,
  ) async {
    if (uids.isEmpty) return <MessageSummary>[];
    await selectFolder(folder);
    final FetchImapResult result = await _client.uidFetchMessages(
      MessageSequence.fromIds(uids, isUid: true),
      'BODY.PEEK[HEADER]',
    );
    return result.messages.map(MessageSummary.fromMime).toList()
      ..sort(
        (MessageSummary a, MessageSummary b) =>
            b.sequenceId.compareTo(a.sequenceId),
      );
  }

  /// Subject, sender or recipient containing [query].
  @override
  Future<List<MessageSummary>> search(
    MailFolder folder,
    String query,
  ) async {
    await selectFolder(folder);
    final String escaped =
        query.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    final SearchImapResult result = await _client.searchMessages(
      searchCriteria:
          'OR OR SUBJECT "$escaped" FROM "$escaped" TO "$escaped"',
    );
    final MessageSequence? matches = result.matchingSequence;
    if (matches == null || matches.isEmpty) return <MessageSummary>[];
    final List<int> newestFirst =
        matches.toList().reversed.take(80).toList();
    return fetchSummariesByUid(folder, newestFirst);
  }

  @override
  Future<void> markUnread(MessageSummary summary) => _client.uidStore(
        MessageSequence.fromId(summary.uid, isUid: true),
        <String>[MessageFlags.seen],
        action: StoreAction.remove,
      );

  @override
  Future<void> setFlagged(MessageSummary summary, bool flagged) =>
      _client.uidStore(
        MessageSequence.fromId(summary.uid, isUid: true),
        <String>[MessageFlags.flagged],
        action: flagged ? StoreAction.add : StoreAction.remove,
      );

  /// Fetches the full message. `BODY[]` rather than `BODY.PEEK[]`, so the
  /// server also sets the `\Seen` flag as a side effect.
  @override
  Future<FullMessage> fetchMessage(MessageSummary summary) async {
    final FetchImapResult result = await _client.uidFetchMessage(
      summary.uid,
      'BODY[]',
    );
    if (result.messages.isEmpty) {
      throw MailException('That message could not be loaded.');
    }
    return FullMessage.fromMime(result.messages.first);
  }

  /// Moves the message to [trashPath] when the server has one, then expunges.
  @override
  Future<void> deleteMessage(
    MessageSummary summary, {
    String? trashPath,
  }) async {
    if (trashPath != null) {
      try {
        await _client.uidCopy(
          MessageSequence.fromId(summary.uid, isUid: true),
          targetMailboxPath: trashPath,
        );
      } catch (_) {
        // No trash folder on this server; fall through to a hard delete.
      }
    }
    await _client.uidStore(
      MessageSequence.fromId(summary.uid, isUid: true),
      <String>[MessageFlags.deleted],
    );
    await _client.expunge();
  }

  @override
  Future<void> send({
    required String to,
    required String body,
    String cc = '',
    String subject = '',
    String password = '',
    List<File> attachments = const <File>[],
  }) async {
    final MessageBuilder builder =
        MessageBuilder.prepareMultipartAlternativeMessage(
      plainText: body,
      htmlText: _asHtml(body),
    )
          ..from = <MailAddress>[MailAddress(account.email, account.email)]
          ..to = _parseAddresses(to)
          ..subject = subject;

    if (cc.trim().isNotEmpty) {
      builder.cc = _parseAddresses(cc);
    }
    for (final File file in attachments) {
      await builder.addFile(
        file,
        MediaSubtype.applicationOctetStream.mediaType,
      );
    }

    final MimeMessage message = builder.buildMimeMessage();
    final SmtpClient smtp = SmtpClient(account.smtpHost, isLogEnabled: false);
    final bool implicitTls = account.smtpPort == 465;
    try {
      await smtp.connectToServer(
        account.smtpHost,
        account.smtpPort,
        isSecure: implicitTls,
      );
      await smtp.ehlo();
      if (!implicitTls) {
        await smtp.startTls();
        await smtp.ehlo();
      }
      if (smtp.serverInfo.supportsAuth(AuthMechanism.plain)) {
        await smtp.authenticate(account.email, password, AuthMechanism.plain);
      } else if (smtp.serverInfo.supportsAuth(AuthMechanism.login)) {
        await smtp.authenticate(account.email, password, AuthMechanism.login);
      } else {
        throw MailException('This server offers no supported sign-in method.');
      }
      final SmtpResponse response = await smtp.sendMessage(message);
      if (!response.isOkStatus) {
        throw MailException('The server rejected the message.');
      }
    } on SmtpException catch (error) {
      throw MailException('Sending failed. $error');
    } finally {
      try {
        await smtp.quit();
      } catch (_) {
        // Already closed.
      }
    }
  }

  @override
  Future<void> disconnect() async {
    final ImapClient? client = _imap;
    _imap = null;
    await _safeLogout(client);
  }

  static Future<void> _safeLogout(ImapClient? client) async {
    if (client == null) return;
    try {
      await client.logout();
    } catch (_) {
      // Connection already gone.
    }
  }

  static List<MailAddress> _parseAddresses(String value) => value
      .split(',')
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .map((String part) => MailAddress('', part))
      .toList();

  static String _asHtml(String text) {
    final String escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    final String body = escaped
        .split(RegExp(r'\n{2,}'))
        .map((String block) => '<p>${block.replaceAll('\n', '<br>')}</p>')
        .join();
    return '<div>$body</div>';
  }

  static String _friendlyImapError(ImapException error) {
    final String text = error.toString().toLowerCase();
    if (text.contains('auth') ||
        text.contains('credential') ||
        text.contains('login') ||
        text.contains('password')) {
      return 'Sign-in was rejected. Most providers need an app password '
          'rather than your account password.';
    }
    return 'Mailbox error. $error';
  }
}
