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
import '../util/removal.dart';
import '../util/search_query.dart';
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
  MailService(
    this.account, {
    bool Function()? reconnectAllowed,
    this.tokenProvider,
  }) : _reconnectAllowed = reconnectAllowed ?? (() => true);

  final AceAccount account;

  /// Read live, so turning automatic reconnection off applies immediately.
  final bool Function() _reconnectAllowed;

  /// A fresh Google access token, for an account that signs in with Google.
  ///
  /// Called at every connect rather than once, because a token lives about an
  /// hour: one fetched when the account was added would be expired by the time
  /// anybody reconnected, and the failure would look like a wrong password.
  final Future<String?> Function()? tokenProvider;

  final RequestQueue _queue = RequestQueue();
  final math.Random _random = math.Random();

  ImapClient? _imap;

  /// Kept in memory only, so a reconnect does not need the user to sign in
  /// again. Never written anywhere. Unused by a Google account, whose token is
  /// fetched fresh instead of remembered.
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
    // `isLogEnabled: false` is not a debug convenience: the protocol log is the
    // `LOGIN` command in full, password included. It stays off in every build.
    final ImapClient client = ImapClient(isLogEnabled: false);
    try {
      // 993 speaks TLS from the first byte; anything else starts plain and is
      // upgraded with STARTTLS before the password is sent — the same shape the
      // SMTP connection below already uses for 465 against everything else.
      //
      // This was `isSecure: true` unconditionally, which is right for 993 and
      // wrong for 143: the server is waiting for STARTTLS, gets a TLS handshake
      // instead, and the sign-in fails with something that says nothing about
      // the port. A provider that offers IMAP only on 143 could not be reached
      // at all.
      //
      // The certificate is still validated by the library in both modes. There
      // is no `badCertificateCallback` anywhere in this app and a test fails the
      // build if one appears — see test/transport_security_test.dart.
      // The account's own setting, which is the port's word for it unless
      // somebody said otherwise in the advanced panel.
      final bool implicitTls =
          account.imapTransport == MailSecurity.implicitTls;
      await client.connectToServer(
        account.imapHost,
        account.imapPort,
        isSecure: implicitTls,
      );
      if (!implicitTls) {
        if (!client.serverInfo.supportsStartTls) {
          // Refused, not downgraded. A server that will not encrypt is a server
          // the password does not go to, and there is no path around this.
          throw const MailConnectionException(
            'This server does not offer a secure connection, so the password '
            'was not sent.',
          );
        }
        await client.startTls();
      }
      if (account.isGoogle) {
        // XOAUTH2: the token is the credential. Gmail has not accepted a
        // password over IMAP since 2022.
        await client.authenticateWithOAuth2(account.email, password);
      } else {
        await client.login(account.email, password);
      }
      final List<MailFolder> folders = await _listFoldersOn(client);
      _imap = client;
      _password = password;
      // Not awaited: signing in should not wait for a second connection that
      // only matters when something is sent.
      unawaited(_warmSmtp(password));
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
    // A Google token has expired by now — it lasts about an hour, and the whole
    // point of the provider is that it can be replaced without asking anyone.
    // A password is remembered, because there is no way to replace it.
    final String? password = account.isGoogle
        ? await tokenProvider?.call()
        : _password;
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
    // Recursive, and that word is the whole bug. A plain LIST answers with the
    // top level only, and every one of Gmail's folders — Sent, Drafts, Spam,
    // Trash, All Mail — is a *child* of the "[Gmail]" container. So a Gmail
    // account listed exactly one folder, Inbox, while Yahoo listed six: the
    // difference was never the provider, it was the LIST.
    final List<Mailbox> mailboxes = await client.listMailboxes(recursive: true);
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
    await _dropSmtp();
  }

  // --- mailbox ------------------------------------------------------------

  @override
  Future<void> selectFolder(MailFolder folder) => _queue.run(
        () => _guard(() => _selectRaw(folder),
            fallback: 'Could not open ${folder.label}.'),
      );

  Future<void> _selectRaw(MailFolder folder) =>
      _client.selectMailboxByPath(folder.path);

  /// A UID is scoped to its mailbox. Reselect the owning folder inside the same
  /// queue slot as the operation, rather than trusting whichever folder a
  /// previous asynchronous UI action happened to leave selected.
  Future<void> _selectSummaryFolder(MessageSummary summary) async {
    final String? path = summary.folderPath;
    if (path != null && path.isNotEmpty) {
      await _client.selectMailboxByPath(path);
    }
  }

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
            return _fetchSummariesRaw(uids, folderPath: folder.path);
          },
          fallback: 'Could not load messages.',
        ),
      );

  /// Assumes the mailbox is already selected. Not queued, so queued callers can
  /// use it without waiting on themselves.
  Future<List<MessageSummary>> _fetchSummariesRaw(
    List<int> uids, {
    required String folderPath,
  }) async {
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
    return result.messages
        .map((MimeMessage message) =>
            MessageSummary.fromMime(message, folderPath: folderPath))
        .toList()
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
            final SearchQuery parsed = SearchQuery.parse(query);

            // A query made only of locally-narrowed operators — `has:attachment`
            // — has no server criteria at all. Returning early on that made the
            // feature unreachable in its only useful form: finding attachments
            // without already knowing a keyword. With nothing searchable on the
            // server, the page is simply the newest messages and the narrowing
            // does the work.
            if (criteria == null && !parsed.narrowsLocally) {
              return <MessageSummary>[];
            }

            // UID SEARCH, not SEARCH. A plain SEARCH answers with *sequence
            // numbers*, which are positions in the mailbox — feeding those to a
            // UID fetch is how a search quietly returns the wrong messages, or
            // none at all.
            final SearchImapResult result = await _client.uidSearchMessages(
              searchCriteria: criteria ?? 'ALL',
            );
            final MessageSequence? matches = result.matchingSequence;
            if (matches == null || matches.isEmpty) return <MessageSummary>[];
            final List<MessageSummary> found = await _fetchSummariesRaw(
              matches.toList().reversed.take(80).toList(),
              folderPath: folder.path,
            );

            // `has:attachment` has no IMAP key, so it narrows the page here.
            // The cost is that it filters what the server sent rather than the
            // whole mailbox, which is the honest limit of not downloading
            // everything to answer one question.
            return parsed.narrowsLocally
                ? found.where(parsed.matches).toList()
                : found;
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
  static String? searchCriteriaFor(String query) =>
      SearchQuery.parse(query).criteria();

  /// Whether this server can remove one message without risking others.
  ///
  /// UIDPLUS is the whole answer. `UID EXPUNGE` (RFC 2359) removes exactly the
  /// UIDs it is given. A server without it offers only the mailbox-wide
  /// `EXPUNGE`, which removes *every* message carrying `\Deleted` — including
  /// ones another client flagged and has not finished with.
  ///
  /// Checking the mailbox first narrows that window but cannot close it:
  /// another client can flag a message between the check and the expunge. So
  /// the policy is to refuse and say why, rather than to guess. Pure, so the
  /// rule can be asserted without a server.
  static bool removalIsSafe({required bool supportsUidPlus}) => supportsUidPlus;

  /// `BODY.PEEK[]` so reading a message does not set `\Seen` as a side effect.
  /// The flag is set deliberately afterwards, which keeps local and server
  /// state in step even when the mark-read call fails.
  @override
  Future<FullMessage> fetchMessage(MessageSummary summary) => _queue.run(
        () => _guard(
          () async {
            await _selectSummaryFolder(summary);
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
            await _selectSummaryFolder(summary);
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
  Future<void> markManySeen(List<MessageSummary> messages) {
    if (messages.isEmpty) return Future<void>.value();
    return _queue.run(
      () => _guard(
        () async {
          await _selectSummaryFolder(messages.first);
          await _client.uidStore(
            _sequenceOf(messages),
            <String>[MessageFlags.seen],
            action: StoreAction.add,
          );
        },
        fallback: 'The messages could not be marked read.',
      ),
    );
  }

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
          () async {
            await _selectSummaryFolder(summary);
            await _client.uidStore(
              MessageSequence.fromId(summary.uid, isUid: true),
              flags,
              action: action,
            );
          },
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
            await _selectSummaryFolder(summary);
            final MessageSequence sequence =
                MessageSequence.fromId(summary.uid, isUid: true);
            // The refusal comes first, before the copy. It used to come after,
            // so a move this server cannot complete left a copy in the target
            // folder and told the user nothing had happened.
            await removeMessage(
              canRemoveSafely: _canRemoveSafely,
              refusal: _removalRefusal,
              copy: () => _copyTo(sequence, targetPath),
              flagAndExpunge: () => _deleteAndExpunge(sequence),
            );
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
            await _selectSummaryFolder(summary);
            final MessageSequence sequence =
                MessageSequence.fromId(summary.uid, isUid: true);

            if (!permanently && trashPath == null) {
              // Before anything is touched, and before the copy below.
              throw const MailRejectedException(
                'This account has no Trash folder, so the message was not '
                'deleted.',
              );
            }

            await removeMessage(
              canRemoveSafely: _canRemoveSafely,
              refusal: _removalRefusal,
              // A permanent delete has nothing to copy; a move to Trash does.
              copy: permanently
                  ? () async {}
                  : () => _copyTo(sequence, trashPath!),
              flagAndExpunge: () => _deleteAndExpunge(sequence),
            );
          },
          fallback: 'The message could not be removed.',
        ),
      );

  /// One UID set for the whole batch: one copy, one flag, one expunge. The
  /// callers group by folder first, so every message here is in the folder the
  /// first one names.
  @override
  Future<void> moveMessages(
    List<MessageSummary> messages,
    String targetPath,
  ) {
    if (messages.isEmpty) return Future<void>.value();
    if (messages.length == 1) return moveMessage(messages.first, targetPath);
    return _queue.run(
      () => _guard(
        () async {
          await _selectSummaryFolder(messages.first);
          final MessageSequence sequence = _sequenceOf(messages);
          await removeMessage(
            canRemoveSafely: _canRemoveSafely,
            refusal: _removalRefusal,
            copy: () => _copyTo(sequence, targetPath),
            flagAndExpunge: () => _deleteAndExpunge(sequence),
          );
        },
        fallback: 'Could not move the messages, so they were left where they were.',
      ),
    );
  }

  @override
  Future<void> deleteMessages(
    List<MessageSummary> messages, {
    String? trashPath,
    bool permanently = false,
  }) {
    if (messages.isEmpty) return Future<void>.value();
    if (messages.length == 1) {
      return deleteMessage(
        messages.first,
        trashPath: trashPath,
        permanently: permanently,
      );
    }
    return _queue.run(
      () => _guard(
        () async {
          if (!permanently && trashPath == null) {
            throw const MailRejectedException(
              'This account has no Trash folder, so the messages were not '
              'deleted.',
            );
          }
          await _selectSummaryFolder(messages.first);
          final MessageSequence sequence = _sequenceOf(messages);
          await removeMessage(
            canRemoveSafely: _canRemoveSafely,
            refusal: _removalRefusal,
            copy: permanently
                ? () async {}
                : () => _copyTo(sequence, trashPath!),
            flagAndExpunge: () => _deleteAndExpunge(sequence),
          );
        },
        fallback: 'The messages could not be removed.',
      ),
    );
  }

  static MessageSequence _sequenceOf(List<MessageSummary> messages) =>
      MessageSequence.fromIds(
        <int>[for (final MessageSummary m in messages) m.uid],
        isUid: true,
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

  /// Whether this server can remove a single message without touching others.
  bool get _canRemoveSafely =>
      removalIsSafe(supportsUidPlus: _client.serverInfo.supportsUidPlus);

  /// What to say when it cannot.
  static const String _removalRefusal =
      'This server cannot remove one message at a time. Removing it would '
      'expunge the whole mailbox, which would also take anything another app '
      'has marked for deletion — so nothing was changed.';

  /// Flags the message `\Deleted`, then expunges exactly that UID.
  ///
  /// Only reached when the server supports UIDPLUS: the callers preflight
  /// through [removeMessage] before anything is copied, so a server that can
  /// only expunge the whole mailbox never gets here.
  Future<void> _deleteAndExpunge(MessageSequence sequence) async {
    await _client.uidStore(sequence, <String>[MessageFlags.deleted]);
    await _client.uidExpunge(sequence);
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
    if (attachments.length > MailLimits.maxAttachmentCount) {
      throw const MailRejectedException(
        'A message can carry at most ${MailLimits.maxAttachmentCount} '
        'attachments.',
      );
    }
    if (attachmentBytes > MailLimits.maxOutboundAttachmentBytes) {
      throw const MailRejectedException(
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
      try {
        // Guess from the name instead of shipping everything as
        // application/octet-stream, so recipients get sensible previews.
        await builder.addFile(file, MediaType.guessFromFileName(file.path));
      } catch (_) {
        // The size check above read the file, and this reads it again. A file
        // can be moved, deleted or locked in between — a cloud-synced folder
        // evicting it is enough — and the raw exception from that is a
        // FileSystemException with a path in it, which is not a sentence to put
        // in front of somebody. Same words as the size check, because it is the
        // same problem.
        throw const MailRejectedException(
          'An attachment could not be read, so nothing was sent.',
        );
      }
    }

    final MimeMessage message = builder.buildMimeMessage();

    // The SMTP connection is kept between sends. Connecting, EHLO, STARTTLS,
    // EHLO and AUTH is most of the time a send takes — several seconds on a
    // phone — and none of it depends on the message. It is opened once, warmed
    // when the mailbox connects, and reopened only when it has gone stale.
    SmtpClient smtp = await _smtpFor(password);
    bool handedOver = false;
    try {
      handedOver = true;
      final SmtpResponse response = await smtp.sendMessage(message);
      if (!response.isOkStatus) {
        await _dropSmtp();
        throw MailErrors.classify(
          SmtpException(smtp, response),
          fallback: 'The server rejected the message.',
        );
      }
    } on MailException {
      rethrow;
    } catch (error) {
      await _dropSmtp();
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
    }

    // The copy in Sent is filed behind the composer closing rather than in
    // front of it. The message has been accepted; waiting on an IMAP append —
    // through the mailbox queue, behind whatever that is doing — made a send
    // feel slower than it was.
    if (sentPath != null) unawaited(_fileSentCopy(message, sentPath));
  }

  /// The live SMTP connection, when there is one.
  SmtpClient? _smtp;
  String? _smtpPassword;

  /// A connection ready to send, reused when it is still good.
  Future<SmtpClient> _smtpFor(String password) async {
    final SmtpClient? existing = _smtp;
    if (existing != null && _smtpPassword == password) {
      try {
        // A connection left idle may have been closed by the server, and EHLO
        // is the cheapest way to find out — and to re-read the capabilities
        // the STARTTLS decision needs.
        await existing.ehlo();
        return existing;
      } catch (_) {
        await _dropSmtp();
      }
    }
    final SmtpClient opened = await _openSmtp(password);
    _smtp = opened;
    _smtpPassword = password;
    return opened;
  }

  /// Connects and signs in. 465 speaks TLS from the first byte; anything else
  /// starts plain and is upgraded with STARTTLS before the password is sent.
  /// Either way the certificate is validated, and there is no path that sends
  /// credentials over an unencrypted connection.
  Future<SmtpClient> _openSmtp(String password) async {
    final SmtpClient smtp = SmtpClient(account.smtpHost, isLogEnabled: false);
    try {
      final bool implicitTls =
          account.smtpTransport == MailSecurity.implicitTls;
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

      if (account.isGoogle) {
        // The token arrives as the "password" here: enough_mail documents
        // XOAUTH2 as taking the token in that argument.
        await smtp.authenticate(account.email, password, AuthMechanism.xoauth2);
      } else if (smtp.serverInfo.supportsAuth(AuthMechanism.plain)) {
        await smtp.authenticate(account.email, password, AuthMechanism.plain);
      } else if (smtp.serverInfo.supportsAuth(AuthMechanism.login)) {
        await smtp.authenticate(account.email, password, AuthMechanism.login);
      } else {
        throw const MailRejectedException(
          'The server offers no sign-in method Ace Mail supports.',
        );
      }
      return smtp;
    } catch (error) {
      await _safeQuit(smtp);
      throw MailErrors.classify(
        error,
        fallback: 'Could not reach ${account.smtpHost}.',
      );
    }
  }

  Future<void> _dropSmtp() async {
    final SmtpClient? smtp = _smtp;
    _smtp = null;
    _smtpPassword = null;
    if (smtp != null) await _safeQuit(smtp);
  }

  /// Opens the sending connection before anybody presses send.
  ///
  /// Best effort and silent: a device that is offline at launch simply opens it
  /// on the first send instead, which is where it would have been anyway.
  Future<void> _warmSmtp(String password) async {
    try {
      await _smtpFor(password);
    } catch (_) {
      // The send will try again, and will say so if it fails.
    }
  }

  /// Best effort: some providers file the sent copy themselves, some do not.
  /// A failure here must not make a delivered message look unsent.
  Future<void> _fileSentCopy(MimeMessage message, String sentPath) async {
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
