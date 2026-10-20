import 'dart:io';

import 'package:enough_mail/enough_mail.dart';

import '../data/limits.dart';
import '../models/ace_account.dart';
import '../models/full_message.dart';
import '../models/mail_folder.dart';
import '../models/message_summary.dart';
import '../util/addresses.dart';
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

  /// Connecting and the first folder listing are one operation. If either half
  /// fails the client is closed and nothing is published, so a retry cannot
  /// leave a second connection open behind a stale one.
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
      final List<MailFolder> folders = await _listFoldersOn(client);
      _imap = client;
      return folders;
    } catch (error) {
      await _safeLogout(client);
      _imap = null;
      throw MailException(
        _describe(error, fallback: 'Could not sign in to ${account.imapHost}.'),
      );
    }
  }

  @override
  Future<List<MailFolder>> listFolders() => _listFoldersOn(_client);

  Future<List<MailFolder>> _listFoldersOn(ImapClient client) async {
    final List<Mailbox> mailboxes = await client.listMailboxes();
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
  Future<void> selectFolder(MailFolder folder) async {
    try {
      await _client.selectMailboxByPath(folder.path);
    } catch (error) {
      throw MailException(
        _describe(error, fallback: 'Could not open ${folder.label}.'),
      );
    }
  }

  /// One cheap SEARCH, newest first, capped. A folder with two hundred thousand
  /// messages should not become a two-hundred-thousand element list in memory.
  @override
  Future<List<int>> listMessageUids(MailFolder folder) async {
    await selectFolder(folder);
    try {
      final SearchImapResult result = await _client.uidSearchMessages(
        searchCriteria: 'ALL',
      );
      final List<int> uids = result.matchingSequence?.toList() ?? <int>[];
      return uids.reversed.take(MailLimits.maxFolderUids).toList();
    } catch (error) {
      throw MailException(
        _describe(error, fallback: 'Could not list ${folder.label}.'),
      );
    }
  }

  /// Headers only — the list never pulls message bodies.
  @override
  Future<List<MessageSummary>> fetchSummariesByUid(
    MailFolder folder,
    List<int> uids,
  ) async {
    if (uids.isEmpty) return <MessageSummary>[];
    await selectFolder(folder);
    try {
      final FetchImapResult result = await _client.uidFetchMessages(
        MessageSequence.fromIds(uids, isUid: true),
        'BODY.PEEK[HEADER]',
      );
      // Order by the UIDs that were asked for, not by sequence numbers.
      // Sequence numbers are positions in the mailbox and move as mail arrives;
      // UIDs are the stable identity.
      final Map<int, int> requested = <int, int>{
        for (int i = 0; i < uids.length; i++) uids[i]: i,
      };
      return result.messages.map(MessageSummary.fromMime).toList()
        ..sort(
          (MessageSummary a, MessageSummary b) =>
              (requested[a.uid] ?? 1 << 30).compareTo(requested[b.uid] ?? 1 << 30),
        );
    } catch (error) {
      throw MailException(
        _describe(error, fallback: 'Could not load messages.'),
      );
    }
  }

  @override
  Future<List<MessageSummary>> search(
    MailFolder folder,
    String query,
  ) async {
    await selectFolder(folder);

    // The library's builder quotes the term but does not escape backslashes, so
    // drop the characters that could break out of the quoted string before it
    // ever reaches it. Its OR term also refuses to nest, which is why this
    // searches sender and subject rather than adding a third branch.
    final String safe =
        query.replaceAll(RegExp(r'[\\\x00-\x1f\x7f]'), ' ').trim();
    if (safe.isEmpty) return <MessageSummary>[];

    try {
      final SearchQueryBuilder builder = SearchQueryBuilder.from(
        safe,
        SearchQueryType.fromOrSubject,
      );
      final SearchImapResult result = await _client.searchMessages(
        searchCriteria: builder.toString(),
      );
      final MessageSequence? matches = result.matchingSequence;
      if (matches == null || matches.isEmpty) return <MessageSummary>[];
      return await fetchSummariesByUid(
        folder,
        matches.toList().reversed.take(80).toList(),
      );
    } catch (error) {
      throw MailException(_describe(error, fallback: 'The search failed.'));
    }
  }

  /// `BODY.PEEK[]` so reading a message does not set `\Seen` as a side effect.
  /// The flag is set deliberately afterwards, which keeps local and server
  /// state in step even when the mark-read call fails.
  @override
  Future<FullMessage> fetchMessage(MessageSummary summary) async {
    try {
      final FetchImapResult result = await _client.uidFetchMessage(
        summary.uid,
        'BODY.PEEK[]',
      );
      if (result.messages.isEmpty) {
        throw MailException('That message could not be loaded.');
      }
      return FullMessage.fromMime(result.messages.first);
    } on MailException {
      rethrow;
    } catch (error) {
      throw MailException(
        _describe(error, fallback: 'That message could not be loaded.'),
      );
    }
  }

  @override
  Future<void> markSeen(MessageSummary summary) => _client.uidStore(
        MessageSequence.fromId(summary.uid, isUid: true),
        <String>[MessageFlags.seen],
        action: StoreAction.add,
      );

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

  /// Moves the message to Trash, then expunges it.
  ///
  /// It deliberately does **not** fall back to a permanent delete when the move
  /// fails. A temporary server error, a full mailbox or a permission problem
  /// would otherwise destroy mail that the user asked to file away. A permanent
  /// delete happens only when the caller asks for one explicitly.
  @override
  Future<void> deleteMessage(
    MessageSummary summary, {
    String? trashPath,
    bool permanently = false,
  }) async {
    final MessageSequence sequence =
        MessageSequence.fromId(summary.uid, isUid: true);

    if (!permanently) {
      if (trashPath == null) {
        throw MailException(
          'This account has no Trash folder, so the message was not deleted.',
        );
      }
      try {
        await _client.uidCopy(sequence, targetMailboxPath: trashPath);
      } catch (error) {
        throw MailException(
          _describe(
            error,
            fallback: 'Could not move the message to Trash, so it was left '
                'untouched.',
          ),
        );
      }
    }

    try {
      await _client.uidStore(sequence, <String>[MessageFlags.deleted]);
      await _client.expunge();
    } catch (error) {
      throw MailException(
        _describe(error, fallback: 'The message could not be removed.'),
      );
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
    String? inReplyTo,
    String? references,
    String? sentPath,
  }) async {
    // Validate before touching the network, so a typo is reported instantly
    // rather than as a server rejection.
    final String? problem = MailAddresses.validate(to, field: 'To') ??
        MailAddresses.validate(cc, field: 'Cc');
    if (problem != null) throw MailException(problem);

    final MessageBuilder builder = MessageBuilder.prepareMultipartAlternativeMessage(
      plainText: body,
      htmlText: _asHtml(body),
    )
      ..from = <MailAddress>[MailAddress(account.email, account.email)]
      ..to = MailAddresses.parse(to)
      ..subject = subject;

    if (cc.trim().isNotEmpty) builder.cc = MailAddresses.parse(cc);
    if (inReplyTo != null && inReplyTo.isNotEmpty) {
      builder.addHeader('In-Reply-To', inReplyTo);
    }
    if (references != null && references.isNotEmpty) {
      builder.addHeader('References', references);
    }

    for (final File file in attachments) {
      // Guess from the name instead of shipping everything as
      // application/octet-stream, so recipients get sensible previews.
      await builder.addFile(file, MediaType.guessFromFileName(file.path));
    }

    final MimeMessage message = builder.buildMimeMessage();

    final SmtpClient smtp = SmtpClient(account.smtpHost, isLogEnabled: false);
    bool handedOver = false;
    try {
      final bool implicitTls = account.smtpPort == 465;
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
        throw MailException(
          'The server offers no sign-in method Ace Mail supports.',
        );
      }

      handedOver = true;
      final SmtpResponse response = await smtp.sendMessage(message);
      if (!response.isOkStatus) {
        throw MailException(
          'The server rejected the message. Check the recipients and try again.',
        );
      }
    } on MailException {
      rethrow;
    } catch (error) {
      if (handedOver) {
        // A dropped connection here is not the same as a rejection: the server
        // may well have delivered it. Never retry automatically.
        throw MailException(
          'The connection dropped after the message reached the server, so '
          'delivery is unconfirmed. Check your Sent folder before sending '
          'again — Ace Mail will not resend it for you.',
        );
      }
      throw MailException(
        _describe(error, fallback: 'Could not reach ${account.smtpHost}.'),
      );
    } finally {
      await _safeQuit(smtp);
    }

    // Best effort: some providers file the sent copy themselves, some do not.
    // A failure here must not make a delivered message look unsent.
    if (sentPath != null) {
      try {
        await _client.appendMessage(
          message,
          targetMailboxPath: sentPath,
          flags: <String>[MessageFlags.seen],
        );
      } catch (_) {
        // The message was still sent.
      }
    }
  }

  @override
  Future<void> disconnect() async {
    final ImapClient? client = _imap;
    _imap = null;
    if (client != null) await _safeLogout(client);
  }

  /// Plain text into a minimal HTML alternative.
  static String _asHtml(String text) {
    final String escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    final String paragraphs = escaped
        .split(RegExp(r'\n{2,}'))
        .map((String block) => '<p>${block.replaceAll('\n', '<br>')}</p>')
        .join();
    return '<div>$paragraphs</div>';
  }

  /// Turns a provider or socket error into something worth showing, without
  /// dumping protocol internals or a stack trace into the interface.
  static String _describe(Object error, {required String fallback}) {
    if (error is MailException) return error.message;

    final String text = error.toString().toLowerCase();
    if (text.contains('auth') ||
        text.contains('credential') ||
        text.contains('invalid password') ||
        text.contains('login failed')) {
      return 'Sign-in was rejected. Most providers need an app password, not '
          'your account password.';
    }
    if (error is SocketException) {
      return '$fallback Check this device\'s network connection.';
    }
    if (text.contains('certificate') || text.contains('handshake')) {
      return '$fallback The secure connection could not be verified.';
    }
    return fallback;
  }

  static Future<void> _safeLogout(ImapClient client) async {
    try {
      await client.logout();
    } catch (_) {
      // Already gone.
    }
  }

  static Future<void> _safeQuit(SmtpClient client) async {
    try {
      await client.quit();
    } catch (_) {
      // Already gone.
    }
  }
}
