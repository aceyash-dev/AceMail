import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

// `hide` because the library exports its own MailException; ours is the
// typed one the app means.
import 'package:enough_mail/enough_mail.dart' hide MailException;

import '../data/limits.dart';
import '../models/ace_account.dart';
import '../models/full_message.dart';
import '../models/mail_folder.dart';
import '../models/message_summary.dart';
import '../util/addresses.dart';
import 'backoff.dart';
import 'mail_errors.dart';
import 'mail_transport.dart';
import 'request_queue.dart';

export 'mail_errors.dart' show
    MailException,
    MailAuthException,
    MailConnectionException,
    MailRejectedException,
    MailUnknownOutcomeException,
    MailServerException;

/// Thin, explicit wrapper over `enough_mail`'s low-level IMAP and SMTP clients.
/// One instance per signed-in account.
///
/// Everything that touches the selected mailbox goes through [_queue], so two
/// operations cannot interleave a `SELECT` with a `FETCH` and read from the
/// wrong folder. A dropped connection is retried once, after a backoff, rather
/// than surfacing as a failure the user has to fix by hand.
class MailService implements MailTransport {
  MailService(this.account, {bool Function()? reconnectAllowed})
      : _reconnectAllowed = reconnectAllowed ?? (() => true);

  final AceAccount account;

  /// Read live, so turning automatic reconnection off applies immediately.
  final bool Function() _reconnectAllowed;

  final RequestQueue _queue = RequestQueue();
  final math.Random _random = math.Random();

  ImapClient? _imap;

  /// Kept in memory only, so a reconnect does not need the user to sign in
  /// again. Never written anywhere.
  String? _password;

  /// Consecutive failed attempts, for the backoff schedule.
  int _attempts = 0;

  bool get isConnected => _imap != null;

  ImapClient get _client {
    final ImapClient? client = _imap;
    if (client == null) throw const MailConnectionException('Not connected.');
    return client;
  }

  // --- connection ---------------------------------------------------------

  /// Connecting and the first folder listing are one operation. If either half
  /// fails the client is closed and nothing is published, so a retry cannot
  /// leave a second connection open behind a stale one.
  @override
  Future<List<MailFolder>> connect(String password) =>
      _queue.run(() => _connectRaw(password));

  Future<List<MailFolder>> _connectRaw(String password) async {
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
      _password = password;
      return folders;
    } catch (error) {
      await _safeLogout(client);
      _imap = null;
      throw MailErrors.classify(
        error,
        fallback: 'Could not sign in to ${account.imapHost}.',
      );
    }
  }

  /// Reconnects inside a queue slot, so nothing else can run mid-handshake.
  Future<void> _reconnectRaw() async {
    final String? password = _password;
    if (password == null) return;

    final ImapClient? stale = _imap;
    _imap = null;
    if (stale != null) await _safeLogout(stale);
    await _connectRaw(password);
  }

  @override
  Future<List<MailFolder>> listFolders() =>
      _queue.run(() => _guard(() => _listFoldersOn(_client),
          fallback: 'Could not list folders.'));

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
  Future<void> disconnect() async {
    // Deliberately not queued: tearing the connection down must not wait behind
    // a command that may never return.
    final ImapClient? client = _imap;
    _imap = null;
    _password = null;
    if (client != null) await _safeLogout(client);
  }

  // --- mailbox ------------------------------------------------------------

  @override
  Future<void> selectFolder(MailFolder folder) => _queue.run(
        () => _guard(() => _selectRaw(folder),
            fallback: 'Could not open ${folder.label}.'),
      );

  Future<void> _selectRaw(MailFolder folder) =>
      _client.selectMailboxByPath(folder.path);

  /// One cheap SEARCH, newest first, capped. A folder with two hundred thousand
  /// messages should not become a two-hundred-thousand element list in memory.
  @override
  Future<List<int>> listMessageUids(MailFolder folder) => _queue.run(
        () => _guard(
          () async {
            await _selectRaw(folder);
            final SearchImapResult result = await _client.uidSearchMessages(
              searchCriteria: 'ALL',
            );
            final List<int> uids = result.matchingSequence?.toList() ?? <int>[];
            return uids.reversed.take(MailLimits.maxFolderUids).toList();
          },
          fallback: 'Could not list ${folder.label}.',
        ),
      );

  /// Headers only — the list never pulls message bodies.
  @override
  Future<List<MessageSummary>> fetchSummariesByUid(
    MailFolder folder,
    List<int> uids,
  ) =>
      _queue.run(
        () => _guard(
          () async {
            if (uids.isEmpty) return <MessageSummary>[];
            await _selectRaw(folder);
            return _fetchSummariesRaw(uids);
          },
          fallback: 'Could not load messages.',
        ),
      );

  /// Assumes the mailbox is already selected. Not queued, so queued callers can
  /// use it without waiting on themselves.
  Future<List<MessageSummary>> _fetchSummariesRaw(List<int> uids) async {
    // Only the fields the list actually shows. A full header block is several
    // times this size, and a page of forty of them is the bulk of what the
    // client downloads to draw a list.
    final FetchImapResult result = await _client.uidFetchMessages(
      MessageSequence.fromIds(uids, isUid: true),
      'BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)]',
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
  }

  @override
  Future<List<MessageSummary>> search(MailFolder folder, String query) =>
      _queue.run(
        () => _guard(
          () async {
            await _selectRaw(folder);

            final String? criteria = searchCriteriaFor(query);
            if (criteria == null) return <MessageSummary>[];

            // UID SEARCH, not SEARCH. A plain SEARCH answers with *sequence
            // numbers*, which are positions in the mailbox — feeding those to a
            // UID fetch is how a search quietly returns the wrong messages, or
            // none at all.
            final SearchImapResult result = await _client.uidSearchMessages(
              searchCriteria: criteria,
            );
            final MessageSequence? matches = result.matchingSequence;
            if (matches == null || matches.isEmpty) return <MessageSummary>[];
            return _fetchSummariesRaw(
              matches.toList().reversed.take(80).toList(),
            );
          },
          fallback: 'The search failed.',
        ),
      );

  /// The criteria a search sends, or null when nothing searchable is left.
  ///
  /// Pure, so the escaping and the query shape can be asserted without a
  /// server. The library's builder quotes the term but does not escape
  /// backslashes, so the characters that could break out of the quoted string
  /// are dropped first. Its OR term also refuses to nest, which is why this
  /// covers sender and subject rather than adding a third branch.
  static String? searchCriteriaFor(String query) {
    final String safe =
        query.replaceAll(RegExp(r'[\\\x00-\x1f\x7f]'), ' ').trim();
    if (safe.isEmpty) return null;
    return SearchQueryBuilder.from(
      safe,
      SearchQueryType.fromOrSubject,
    ).toString();
  }

  /// Whether an expunge can be trusted not to take messages it was not asked
  /// to.
  ///
  /// With UIDPLUS the server expunges exactly the UIDs given, so it is always
  /// safe. Without it the only expunge is mailbox-wide, which removes
  /// everything carrying `\Deleted` — so it is safe only when the mailbox holds
  /// no deletions but ours. Pure, so the rule can be asserted without a server.
  static bool expungeIsSafe({
    required bool supportsUidPlus,
    required Set<int> deletedUids,
    required Set<int> ourUids,
  }) {
    if (supportsUidPlus) return true;
    return deletedUids.difference(ourUids).isEmpty;
  }

  /// `BODY.PEEK[]` so reading a message does not set `\Seen` as a side effect.
  /// The flag is set deliberately afterwards, which keeps local and server
  /// state in step even when the mark-read call fails.
  @override
  Future<FullMessage> fetchMessage(MessageSummary summary) => _queue.run(
        () => _guard(
          () async {
            final FetchImapResult result = await _client.uidFetchMessage(
              summary.uid,
              'BODY.PEEK[]',
            );
            if (result.messages.isEmpty) {
              throw const MailServerException(
                'That message could not be loaded.',
              );
            }
            return FullMessage.fromMime(result.messages.first);
          },
          fallback: 'That message could not be loaded.',
        ),
      );

  /// A bounded slice of the body. The partial fetch is a raw string on
  /// purpose: a truncated multipart body does not parse as MIME, and the code
  /// in a one-time-password mail is in the first few hundred bytes anyway.
  @override
  Future<String> fetchPreview(
    MessageSummary summary, {
    int bytes = MailLimits.previewBytes,
  }) =>
      _queue.run(
        () => _guard(
          () async {
            final FetchImapResult result = await _client.uidFetchMessage(
              summary.uid,
              'BODY.PEEK[TEXT]<0.$bytes>',
            );
            if (result.messages.isEmpty) return '';
            return result.messages.first.decodeTextPlainPart() ??
                result.messages.first.decodeTextHtmlPart() ??
                '';
          },
          fallback: 'Could not read a preview.',
        ),
      );

  // --- flags --------------------------------------------------------------

  @override
  Future<void> markSeen(MessageSummary summary) => _store(
        summary,
        <String>[MessageFlags.seen],
        StoreAction.add,
        fallback: 'The message could not be marked read.',
      );

  @override
  Future<void> markUnread(MessageSummary summary) => _store(
        summary,
        <String>[MessageFlags.seen],
        StoreAction.remove,
        fallback: 'The message could not be marked unread.',
      );

  @override
  Future<void> setFlagged(MessageSummary summary, bool flagged) => _store(
        summary,
        <String>[MessageFlags.flagged],
        flagged ? StoreAction.add : StoreAction.remove,
        fallback: 'The flag could not be changed.',
      );

  Future<void> _store(
    MessageSummary summary,
    List<String> flags,
    StoreAction action, {
    required String fallback,
  }) =>
      _queue.run(
        () => _guard(
          () => _client.uidStore(
            MessageSequence.fromId(summary.uid, isUid: true),
            flags,
            action: action,
          ),
          fallback: fallback,
        ),
      );

  // --- moving and deleting ------------------------------------------------

  /// Copies the message to [targetPath] and removes it from the folder it was
  /// in. Used for archive.
  @override
  Future<void> moveMessage(MessageSummary summary, String targetPath) =>
      _queue.run(
        () => _guard(
          () async {
            final MessageSequence sequence =
                MessageSequence.fromId(summary.uid, isUid: true);
            await _copyTo(sequence, targetPath);
            await _deleteAndExpunge(sequence);
          },
          fallback: 'Could not move the message, so it was left where it was.',
        ),
      );

  /// Moves the message to Trash, then expunges it.
  ///
  /// It deliberately does **not** fall back to a permanent delete when the move
  /// fails. A temporary server error, a full mailbox or a permission problem
  /// would otherwise destroy mail the user asked to file away.
  @override
  Future<void> deleteMessage(
    MessageSummary summary, {
    String? trashPath,
    bool permanently = false,
  }) =>
      _queue.run(
        () => _guard(
          () async {
            final MessageSequence sequence =
                MessageSequence.fromId(summary.uid, isUid: true);

            if (!permanently) {
              if (trashPath == null) {
                throw const MailRejectedException(
                  'This account has no Trash folder, so the message was not '
                  'deleted.',
                );
              }
              await _copyTo(sequence, trashPath);
            }

            await _deleteAndExpunge(sequence);
          },
          fallback: 'The message could not be removed.',
        ),
      );

  Future<void> _copyTo(MessageSequence sequence, String targetPath) async {
    try {
      await _client.uidCopy(sequence, targetMailboxPath: targetPath);
    } catch (error) {
      throw MailErrors.classify(
        error,
        fallback: 'Could not move the message, so it was left untouched.',
      );
    }
  }

  /// Flags the message `\Deleted`, then removes it.
  ///
  /// The removal needs an EXPUNGE, and the only one a server without UIDPLUS
  /// offers is mailbox-wide: it takes **every** message carrying `\Deleted`,
  /// including ones another client flagged and has not finished with. So the
  /// mailbox is checked *before* anything is flagged, and the operation is
  /// refused if it could take a message it was not asked to. Refusing is
  /// recoverable; an expunge is not.
  Future<void> _deleteAndExpunge(MessageSequence sequence) async {
    if (!expungeIsSafe(
      supportsUidPlus: _client.serverInfo.supportsUidPlus,
      deletedUids: await _deletedUids(),
      ourUids: sequence.toList().toSet(),
    )) {
      throw const MailRejectedException(
        'This server cannot delete a single message at a time, and other '
        'messages are already marked for deletion — by another app, most '
        'likely. Nothing was removed. Finish those deletions first, then try '
        'again.',
      );
    }
    await _client.uidStore(sequence, <String>[MessageFlags.deleted]);
    await _expungeOnly(sequence);
  }

  /// The UIDs currently flagged `\Deleted` in the selected mailbox.
  Future<Set<int>> _deletedUids() async {
    final SearchImapResult result =
        await _client.uidSearchMessages(searchCriteria: 'DELETED');
    return (result.matchingSequence?.toList() ?? <int>[]).toSet();
  }

  /// Expunges the message just flagged.
  ///
  /// A bare `EXPUNGE` removes **every** message in the mailbox carrying
  /// `\Deleted`. `UID EXPUNGE` (RFC 2359) removes exactly one. A server that
  /// does not advertise UIDPLUS only offers the mailbox-wide form — which is
  /// why [_deleteAndExpunge] checked first that it can only take ours.
  Future<void> _expungeOnly(MessageSequence sequence) async {
    if (_client.serverInfo.supportsUidPlus) {
      await _client.uidExpunge(sequence);
      return;
    }
    await _client.expunge();
  }

  // --- sending ------------------------------------------------------------

  @override
  Future<void> send({
    required String to,
    required String body,
    String cc = '',
    String bcc = '',
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
        MailAddresses.validate(cc, field: 'Cc') ??
        MailAddresses.validate(bcc, field: 'Bcc');
    if (problem != null) throw MailRejectedException(problem);

    // The screen caps attachments too, but the service is the last gate before
    // the network: a caller that does not go through the screen must not be
    // able to send an unbounded message, and a file that has moved since it was
    // picked must be caught here rather than half-way through the transfer.
    int attachmentBytes = 0;
    for (final File file in attachments) {
      final int size;
      try {
        size = await file.length();
      } catch (_) {
        throw const MailRejectedException(
          'An attachment could not be read, so nothing was sent.',
        );
      }
      attachmentBytes += size;
    }
    if (attachmentBytes > MailLimits.maxOutboundAttachmentBytes) {
      throw MailRejectedException(
        'Attachments are limited to '
        '${MailLimits.maxOutboundAttachmentBytes ~/ (1024 * 1024)} MB in total.',
      );
    }

    final MessageBuilder builder =
        MessageBuilder.prepareMultipartAlternativeMessage(
      plainText: body,
      htmlText: _asHtml(body),
    )
          ..from = <MailAddress>[MailAddress(account.email, account.email)]
          ..to = MailAddresses.parse(to)
          ..subject = subject;

    if (cc.trim().isNotEmpty) builder.cc = MailAddresses.parse(cc);
    if (bcc.trim().isNotEmpty) builder.bcc = MailAddresses.parse(bcc);
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

    // SMTP is a separate connection from IMAP, so this does not go through the
    // mailbox queue.
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
        throw const MailRejectedException(
          'The server offers no sign-in method Ace Mail supports.',
        );
      }

      handedOver = true;
      final SmtpResponse response = await smtp.sendMessage(message);
      if (!response.isOkStatus) {
        throw MailErrors.classify(
          SmtpException(smtp, response),
          fallback: 'The server rejected the message.',
        );
      }
    } on MailException {
      rethrow;
    } catch (error) {
      if (handedOver) {
        // A dropped connection here is not the same as a rejection: the server
        // may well have delivered it. Never retry automatically.
        throw const MailUnknownOutcomeException(
          'The connection dropped after the message reached the server, so '
          'delivery is unconfirmed. Check your Sent folder before sending '
          'again — Ace Mail will not resend it for you.',
        );
      }
      throw MailErrors.classify(
        error,
        fallback: 'Could not reach ${account.smtpHost}.',
      );
    } finally {
      await _safeQuit(smtp);
    }

    // Best effort: some providers file the sent copy themselves, some do not.
    // A failure here must not make a delivered message look unsent.
    if (sentPath != null) {
      try {
        await _queue.run(
          () => _client.appendMessage(
            message,
            targetMailboxPath: sentPath,
            flags: <String>[MessageFlags.seen],
          ),
        );
      } catch (_) {
        // The message was still sent.
      }
    }
  }

  // --- retry policy -------------------------------------------------------

  /// Classifies a failure, and retries **once** after a backoff if the
  /// connection dropped rather than the command failing.
  ///
  /// Only connection failures are retried: a rejection will be rejected again,
  /// and an unknown delivery outcome must never be repeated.
  Future<T> _guard<T>(
    Future<T> Function() action, {
    required String fallback,
  }) async {
    try {
      final T value = await action();
      _attempts = 0; // a clean call resets the schedule
      return value;
    } catch (error) {
      final MailException failure =
          MailErrors.classify(error, fallback: fallback);

      final bool retryable = failure is MailConnectionException &&
          _reconnectAllowed() &&
          _password != null &&
          Backoff.worthRetrying(_attempts + 1);
      if (!retryable) throw failure;

      await Future<void>.delayed(
        Backoff.delayFor(_attempts + 1, jitter: _random.nextDouble()),
      );
      _attempts++;

      await _reconnectRaw();
      try {
        return await action();
      } catch (error) {
        throw MailErrors.classify(error, fallback: fallback);
      }
    }
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
