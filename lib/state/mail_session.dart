import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../util/redact.dart';
import '../data/limits.dart';
import '../data/local_store.dart';
import '../services/notifications.dart';
import '../data/preferences.dart';
import '../models/ace_account.dart';
import '../models/full_message.dart';
import '../models/mail_folder.dart';
import '../models/message_sort.dart';
import '../models/message_summary.dart';
import '../util/otp.dart';
import '../services/contacts.dart';
import '../services/google_auth.dart';
import '../services/mail_service.dart';
import '../services/mail_transport.dart';

/// One signed-in account: its connection, its folders, its open message.
///
/// The app can hold several sessions at once and switch between them, so all
/// per-account state lives here rather than on the app-wide controller.
class MailSession extends ChangeNotifier {
  MailSession({
    required this.account,
    required this.password,
    MailTransport? transport,
    Preferences? preferences,
    LocalStore? store,
  })  : _injected = transport,
        _preferences = preferences,
        _store = store;

  /// The encrypted local store, when there is one. Read messages are kept here
  /// so a message opens without the network — and so what is kept is sealed.

  final AceAccount account;
  final String password;
  final MailTransport? _injected;

  /// Read live, so toggling "mark as read when opened" applies to the very
  /// next message without rebuilding the session.
  final Preferences? _preferences;

  final LocalStore? _store;

  bool get _markAsRead => _preferences?.markAsReadOnOpen ?? true;

  /// The default page size, for callers with no settings to hand.
  static const int pageSize = 40;

  /// How many messages a page holds, from the user's setting.
  int get _pageSize => _preferences?.pageSize.count ?? pageSize;

  /// Providers that file a copy of what you send without being asked. Adding a
  /// second copy ourselves is how you end up with duplicates in Sent.
  static const Set<String> _filesSentItself = <String>{
    'gmail.com', 'googlemail.com',
    'outlook.com', 'hotmail.com', 'live.com', 'msn.com',
    'icloud.com', 'me.com', 'mac.com',
    'yahoo.com', 'yahoo.in', 'ymail.com',
  };

  late final MailTransport _transport = _injected ??
      MailService(
        account,
        reconnectAllowed: () => _preferences?.autoReconnect ?? true,
        // Only a Google account has a token to fetch. A password account's
        // secret is remembered by the service, because there is no way to
        // replace it.
        tokenProvider: account.isGoogle ? () => GoogleAuth.token(account.email) : null,
      );

  /// The secret for a handshake: a password, or a fresh Google token.
  ///
  /// A password is returned synchronously — it is already here, and making the
  /// caller wait a turn of the event loop for something that cannot change is
  /// latency added to every connection for nothing.
  ///
  /// A Google token is fetched at the moment it is needed rather than kept,
  /// because it lives about an hour and a mailbox that reconnects in the
  /// afternoon needs one that is valid now. Throws with
  /// [GoogleAuthException.needsSignIn] when Google wants the user back, which
  /// the screen turns into an offer to sign in rather than an error.
  Future<String> _secret() {
    if (!account.isGoogle) return Future<String>.value(password);
    return GoogleAuth.token(account.email).then((String? token) {
      if (token == null) {
        needsGoogleSignIn = true;
        throw const GoogleAuthException(
          'Sign in to Google again to reach this mailbox.',
          needsSignIn: true,
        );
      }
      return token;
    });
  }

  bool connecting = false;
  String? errorMessage;

  /// What to call the person whose mail this is.
  ///
  /// Google says outright. Any other provider has to be asked, and the one place
  /// a person writes their own name is in the mail they send — so the newest
  /// message in Sent carries it in its `From` header. Looked up once, in the
  /// background, because a greeting is not worth a delay before the mail
  /// appears.
  String? displayName;
  bool _nameLookupTried = false;

  /// True when Google wants the person back: the grant was withdrawn, or it
  /// never covered the mail scope. Distinct from a connection failure, because
  /// the answer is a sign-in rather than a retry.
  bool needsGoogleSignIn = false;

  List<MailFolder> folders = <MailFolder>[];
  MailFolder? selectedFolder;

  /// How much is unread in this account's inbox.
  ///
  /// Read from the folder list rather than the message page: the page is one
  /// fetch of forty, and the count is about the whole mailbox.
  int get inboxUnseen {
    for (final MailFolder folder in folders) {
      if (folder.role == FolderRole.inbox) return folder.unseen;
    }
    return 0;
  }

  /// Moves a folder's unread count with what just happened to a message.
  ///
  /// The number in the rail badge and in the greeting above the list comes from
  /// the server's `STATUS`, which is only as fresh as the last folder listing.
  /// Reading, deleting or un-reading a message changes the truth *now*, and a
  /// greeting that still says "3 unread" after you have read all three is worse
  /// than saying nothing: it is the app telling you something it knows is not
  /// so. The local count moves with the local action; the next listing replaces
  /// it with the server's own number.
  ///
  /// Never negative — a server count that started too low, plus a local
  /// subtraction, must not leave a folder owing mail.
  void _adjustUnseen(String? path, int delta) {
    if (delta == 0 || path == null) return;
    final int index = folders.indexWhere((MailFolder f) => f.path == path);
    if (index == -1) return;
    final MailFolder folder = folders[index];
    final int next = folder.unseen + delta;
    if (next == folder.unseen) return;
    folders = List<MailFolder>.of(folders)
      ..[index] = folder.copyWith(unseen: next < 0 ? 0 : next);
  }

  /// Puts this session on its own inbox.
  ///
  /// What the unified view is built from: every account showing its inbox at
  /// once, so the merge is a concatenation rather than a second set of fetches.
  /// A session that has no inbox — a provider with an unusual LIST — stays where
  /// it is and contributes whatever it is showing.
  Future<void> showInbox() async {
    final MailFolder? inbox = _firstWhereOrNull(
      folders,
      (MailFolder f) => f.role == FolderRole.inbox,
    );
    if (inbox == null || selectedFolder?.path == inbox.path) return;
    await openFolder(inbox);
  }
  List<MessageSummary> messages = <MessageSummary>[];
  MessageSummary? openSummary;
  FullMessage? openMessage;

  bool loadingMessages = false;

  /// The last page of each folder, so going back to one shows it at once and
  /// refreshes behind you.
  ///
  /// Bounded by folder count, not by age: a session has a handful of folders,
  /// and a stale page that is replaced a moment later is a much better
  /// experience than a blank one.
  final Map<String, List<MessageSummary>> _pageCache =
      <String, List<MessageSummary>>{};

  /// The UIDVALIDITY each cached page was written under.
  ///
  /// UIDs are only meaningful within one generation of a mailbox. If the server
  /// renumbers it, a cached row's uid now points at a *different* message — and
  /// opening that row would show somebody the wrong mail, which is worse than
  /// showing them a spinner for a moment. So a page from a generation that is
  /// no longer current is not shown at all.
  final Map<String, int?> _cacheValidity = <String, int?>{};

  /// Codes found in bodies, keyed by folder path and then uid, so a refresh
  /// does not refetch the same message.
  ///
  /// Keyed by folder because a uid is unique only *within* a folder. A cache by
  /// uid alone is a session-wide one, so a code found for uid 42 in the inbox
  /// could be shown — and copied — on a different uid 42 in another folder, on
  /// a message that has no code at all. A wrong code is worse than none.
  final Map<String, Map<int, String?>> _bodyCodes =
      <String, Map<int, String?>>{};
  bool _detecting = false;

  /// True while reloading a folder that is already on screen. The contents stay
  /// put — a refresh must not blank the list out from under the reader.
  bool refreshing = false;
  bool loadingMessage = false;
  bool loadingMore = false;

  /// Every UID in the selected folder, newest first — the paging cursor.
  List<int> _uids = <int>[];

  /// The uids picked out by long-press. Non-empty means the list is in
  /// selection mode, and a tap toggles rather than opens.
  final Set<int> selected = <int>{};

  bool get selecting => selected.isNotEmpty;

  bool isSelected(int uid) => selected.contains(uid);

  void toggleSelect(int uid) {
    if (!selected.remove(uid)) selected.add(uid);
    _notify();
  }

  void clearSelection() {
    if (selected.isEmpty) return;
    selected.clear();
    _notify();
  }

  /// The picked messages, in the order they appear on screen.
  List<MessageSummary> get selectedMessages =>
      visibleMessages.where((MessageSummary m) => selected.contains(m.uid)).toList();

  /// Runs [action] over everything picked, then clears the selection.
  ///
  /// Sequential on purpose: the transport serialises these anyway, and a
  /// failure part-way through leaves the ones that succeeded selected, so it is
  /// obvious what did not happen.
  Future<void> forEachSelected(
    Future<void> Function(MessageSummary message) action,
  ) async {
    final List<MessageSummary> picked =
        List<MessageSummary>.of(selectedMessages);
    if (picked.isEmpty) return;

    // Gone from the list before the first round-trip, not one at a time as each
    // finishes. Deleting twenty messages is twenty round-trips, and watching
    // twenty rows disappear over several seconds reads as "it is doing them one
    // by one" — because it was. They leave the screen the moment you asked.
    final Set<int> leaving = picked.map((MessageSummary m) => m.uid).toSet();
    messages =
        messages.where((MessageSummary m) => !leaving.contains(m.uid)).toList();
    _uids = _uids.where((int uid) => !leaving.contains(uid)).toList();
    _notify();

    bool anyFailed = false;
    for (final MessageSummary message in picked) {
      try {
        await action(message);
        selected.remove(message.uid);
      } catch (_) {
        // Left selected, so the failure is visible rather than silent — and the
        // row comes back, because a message that is still there must not look
        // as though it went.
        anyFailed = true;
      }
    }
    if (anyFailed) {
      await refreshMessages();
    }
    _notify();
  }

  /// Deletes everything picked in as few round-trips as the server allows.
  ///
  /// [forEachSelected] is one command per message, which is what the list used
  /// to do and why deleting twenty read as "one by one". This sends the picked
  /// messages as a set: one command per folder, because a set of UIDs only means
  /// something inside the one mailbox it came from.
  Future<void> deleteSelected({bool permanently = false}) => _removeSelected(
        (List<MessageSummary> group) => _transport.deleteMessages(
          group,
          trashPath: trashPath,
          permanently: permanently,
        ),
      );

  /// Archives everything picked, as one batch per folder.
  Future<void> archiveSelected() async {
    final String? path = _folderPathFor(FolderRole.archive);
    if (path == null) {
      errorMessage = 'This account has no Archive folder.';
      _notify();
      return;
    }
    await _removeSelected(
      (List<MessageSummary> group) => _transport.moveMessages(group, path),
    );
  }

  Future<void> _removeSelected(
    Future<void> Function(List<MessageSummary> group) action,
  ) async {
    if (!_connected) return;
    final List<MessageSummary> picked = List<MessageSummary>.of(selectedMessages);
    if (picked.isEmpty) return;

    // Off the screen before the first round-trip, the same as [forEachSelected].
    final Set<int> leaving = picked.map((MessageSummary m) => m.uid).toSet();
    messages =
        messages.where((MessageSummary m) => !leaving.contains(m.uid)).toList();
    _uids = _uids.where((int uid) => !leaving.contains(uid)).toList();
    _notify();

    // Grouped by the folder each message came from. In the unified view one
    // list holds several mailboxes, and a UID is only unique inside its own.
    final Map<String?, List<MessageSummary>> byFolder =
        <String?, List<MessageSummary>>{};
    for (final MessageSummary m in picked) {
      byFolder
          .putIfAbsent(m.folderPath ?? selectedFolder?.path, () => <MessageSummary>[])
          .add(m);
    }

    bool anyFailed = false;
    for (final List<MessageSummary> group in byFolder.values) {
      try {
        await action(group);
        for (final MessageSummary m in group) {
          selected.remove(m.uid);
          // A batch command has no per-message _runOn to carry the count, so it
          // is carried here: every unread message that just left is one less
          // waiting.
          if (!m.isSeen) {
            _adjustUnseen(m.folderPath ?? selectedFolder?.path, -1);
          }
        }
      } catch (error) {
        // Failed rows come back and stay picked, so nothing is hidden.
        anyFailed = true;
        errorMessage = error.toString();
      }
    }
    if (anyFailed) await refreshMessages();
    _notify();
  }

  /// Which quick filter is applied to the page. Transient by design: it is a
  /// way of looking at what is loaded, not a saved preference.
  MessageFilter filter = MessageFilter.all;

  /// The order the page is shown in, from the user's setting.
  MessageSort get sort => _preferences?.messageSort ?? MessageSort.newest;

  /// The page, filtered and sorted. What the list actually renders.
  List<MessageSummary> get visibleMessages {
    // One reading of the clock for the whole pass, not one per message.
    final DateTime now = DateTime.now();
    // Blocked senders are dropped first, and always: a block that only applied
    // to some views would be a block that leaked.
    final List<MessageSummary> allowed = messages
        .where((MessageSummary m) => !Contacts.isBlocked(m.fromEmail))
        .toList();
    final List<MessageSummary> matching = filter == MessageFilter.all
        ? allowed
        : allowed
            .where((MessageSummary m) => filter.matches(m, now: now))
            .toList();
    return sort.apply(matching);
  }

  void setFilter(MessageFilter value) {
    if (filter == value) return;
    filter = value;
    _notify();
  }

  /// The query in force, or null when the folder is simply being listed.
  String? searchQuery;

  bool _connected = false;
  bool _disposed = false;
  Future<bool>? _connecting;

  /// Request generations. Every listing carries the token it was started with,
  /// and a response is only applied if it is still the newest one — otherwise
  /// switching folders quickly lets a slow earlier request overwrite the newer
  /// selection.
  int _folderToken = 0;
  int _messageToken = 0;

  bool get isReady => _connected;

  bool get hasMore => searchQuery == null && messages.length < _uids.length;

  String? get trashPath => _folderPathFor(FolderRole.trash);

  String? get sentPath => _folderPathFor(FolderRole.sent);

  bool get canDeleteSafely => trashPath != null;

  String? _folderPathFor(FolderRole role) {
    for (final MailFolder folder in folders) {
      if (folder.role == role) return folder.path;
    }
    return null;
  }

  /// Connects at most once. A switch that arrives while the first attempt is
  /// still running joins that attempt instead of opening a second connection.
  Future<bool> connect() {
    final Future<bool>? inFlight = _connecting;
    if (inFlight != null) return inFlight;
    if (_connected) return Future<bool>.value(true);
    final Future<bool> attempt = _connect();
    _connecting = attempt;
    return attempt;
  }

  Future<bool> _connect() async {
    connecting = true;
    errorMessage = null;
    _notify();

    try {
      // The password path is untouched by the await: `_secret` is only
      // asynchronous for an account that has a token to fetch.
      final String secret = account.isGoogle ? await _secret() : password;
      final List<MailFolder> loaded = await _transport.connect(secret);

      // The session may have been abandoned while we were connecting; do not
      // leave a live connection behind for a screen that no longer exists.
      if (_disposed) {
        unawaited(_transport.disconnect());
        return false;
      }

      folders = loaded;
      _connected = true;
      needsGoogleSignIn = false;
    // Opening the app is seeing the mail: whatever the background check put in
    // the shade for this account is no longer news.
    unawaited(AceNotifications.clear(account.email));
      connecting = false;
      _notify();

      // Not awaited: the greeting can say "Good morning" for a moment and
      // "Good morning, Yash" a moment later, which is better than the mail
      // waiting on a name.
      unawaited(_resolveDisplayName());

      final MailFolder? inbox =
          _firstWhereOrNull(folders, (MailFolder f) => f.role == FolderRole.inbox) ??
              _firstWhereOrNull(folders, (MailFolder _) => true);
      if (inbox != null) await openFolder(inbox);
      return true;
    } catch (error) {
      errorMessage = error.toString();
      connecting = false;
      _connecting = null; // let a later attempt try again
      _notify();
      return false;
    }
  }

  /// Finds the account holder's own name, once.
  Future<void> _resolveDisplayName() async {
    if (_nameLookupTried || displayName != null) return;
    _nameLookupTried = true;

    try {
      if (account.isGoogle) {
        displayName = await GoogleAuth.knownName();
      } else {
        final MailFolder? sent =
            _firstWhereOrNull(folders, (MailFolder f) => f.role == FolderRole.sent);
        if (sent == null) return;
        // The newest sent message, and only its headers: the display name is in
        // the From line, and that is the name this person chose for themselves.
        final List<int> uids = await _transport.listMessageUids(sent);
        if (uids.isEmpty) return;
        // `first`, not `last`: `listMessageUids` is documented newest-first, so
        // the last of the page is the *oldest* of it — which is the message a
        // person wrote longest ago, and the least likely to carry the name they
        // use now. The line above says "the newest sent message"; this is the
        // line that has to mean it.
        final List<MessageSummary> newest =
            await _transport.fetchSummariesByUid(sent, <int>[uids.first]);
        if (newest.isEmpty) return;
        final String name = newest.first.fromName.trim();
        // A name equal to the address is not a name: it is a client that did
        // not find one, and greeting somebody by their email is worse than not
        // greeting them by name at all.
        if (name.isNotEmpty &&
            name.toLowerCase() != account.email.toLowerCase()) {
          displayName = name;
        }
      }
    } catch (_) {
      // A name is a nicety. If the lookup fails the greeting simply has no name
      // in it, which is exactly what it did before this existed.
    }
    if (displayName != null && !_disposed) _notify();
  }

  Future<void> openFolder(MailFolder folder, {bool refresh = false}) async {
    if (!_connected) return;

    final int token = ++_folderToken;
    _messageToken++; // a body fetch from the previous folder is now stale
    final bool sameFolder = selectedFolder?.path == folder.path;
    // Reloading the folder already on screen keeps its contents until the new
    // ones arrive; switching folders starts clean, because the old rows belong
    // to a different mailbox.
    final bool keepContents = refresh && sameFolder && messages.isNotEmpty;

    selectedFolder = folder;
    searchQuery = null;
    openMessage = null;
    openSummary = null;
    errorMessage = null;
    // A selection belongs to the folder it was made in. A uid is unique only
    // within a folder, so carrying one across a folder change would leave the
    // list in selection mode and let Archive or Delete act on an unrelated
    // message that happens to share a uid.
    selected.clear();

    if (keepContents) {
      refreshing = true;
    } else {
      // A cached page, when there is one: the folder appears immediately and
      // the fetch below replaces it. This is the difference between a folder
      // that opens and a folder that loads.
      final List<MessageSummary>? cached = _pageCache[folder.path];
      final int? cachedUnder = _cacheValidity[folder.path];
      final bool sameGeneration =
          sameMailboxGeneration(cachedUnder, folder.uidValidity);
      if (cached != null && cached.isNotEmpty && sameGeneration) {
        messages = List<MessageSummary>.of(cached);
        refreshing = true;
      } else {
        // A cache from a generation that has gone, or one nobody can vouch for.
        _pageCache.remove(folder.path);
        _cacheValidity.remove(folder.path);
        messages = <MessageSummary>[];
        _uids = <int>[];
        loadingMessages = true;
      }
    }
    _notify();

    try {
      final List<int> uids = await _transport.listMessageUids(folder);
      final List<MessageSummary> page = await _transport.fetchSummariesByUid(
        folder,
        uids.take(_pageSize).toList(),
      );
      if (token != _folderToken) return; // a newer folder won
      _uids = uids;
      messages = page;
      // The address book grows as mail loads: the people who actually write to
      // you, rather than a list somebody has to build by hand.
      Contacts.observe(page);
      if (_pageCache.length > 24) {
        _pageCache.clear();
        _cacheValidity.clear();
      }
      _pageCache[folder.path] = List<MessageSummary>.of(page);
      _cacheValidity[folder.path] = folder.uidValidity;
      unawaited(_detectCodes());
    } catch (error) {
      if (token != _folderToken) return;
      errorMessage = error.toString();
    } finally {
      if (token == _folderToken) {
        loadingMessages = false;
        refreshing = false;
        _notify();
      }
    }
  }

  /// Looks for one-time codes the subject did not give up.
  ///
  /// Best effort and bounded: only mail whose subject talks about a code, only
  /// a handful of rows, and only after the list is already on screen. A code is
  /// a convenience, so nothing here is allowed to hold up or break the list.
  Future<void> _detectCodes() async {
    if (_detecting) return;
    if (!(_preferences?.detectCodes ?? true)) return;

    final int token = _folderToken;
    _detecting = true;
    bool touched = false;
    try {
      final List<MessageSummary> candidates = messages
          .where((MessageSummary m) =>
              m.otp == null && OtpDetector.looksLikeCodeMail(m.subject))
          .take(MailLimits.codeLookups)
          .toList();
      if (candidates.isEmpty) return;

      for (final MessageSummary summary in candidates) {
        if (!_connected || token != _folderToken) return;

        final String? code = await _codeFor(selectedFolder?.path ?? '', summary);

        if (code != null && token == _folderToken) {
          _applyCodeQuietly(summary.uid, code);
          touched = true;
        }
      }
    } catch (_) {
      // Never let a convenience break the list.
    } finally {
      _detecting = false;
      if (touched && token == _folderToken) {
        // One copy of the page and one rebuild for the whole pass. Notifying —
        // or remembering — per code found meant a folder load copied the list
        // and rebuilt it once per message.
        _rememberPage();
        _notify();
      }
    }
  }

  /// The one-time code for [summary] in [folder], cached per folder.
  ///
  /// The cache is re-read after the fetch: the await gives another pass time to
  /// run, and a code belongs to the folder it was found in.
  Future<String?> _codeFor(String folder, MessageSummary summary) async {
    final Map<int, String?> cached = _codesFor(folder);
    if (cached.containsKey(summary.uid)) return cached[summary.uid];
    final String? code =
        OtpDetector.findInBody(await _transport.fetchPreview(summary));
    _codesFor(folder)[summary.uid] = code;
    return code;
  }

  /// One folder's slice of the code cache, bounded so a long session over many
  /// folders cannot grow it without end.
  Map<int, String?> _codesFor(String folder) {
    if (_bodyCodes.length > 400) _bodyCodes.clear();
    return _bodyCodes.putIfAbsent(folder, () => <int, String?>{});
  }

  /// Updates the cache after a flag or a read changes on a row, so going back
  /// to the folder does not undo what you just did.
  void _rememberPage() {
    final MailFolder? folder = selectedFolder;
    if (folder == null || messages.isEmpty) return;
    _pageCache[folder.path] = List<MessageSummary>.of(messages);
  }

  /// Applies a code without notifying.
  ///
  /// The caller notifies once when the pass is done. Notifying per message made
  /// a folder load rebuild the whole list up to a dozen times — one rebuild per
  /// code found — which is exactly the kind of thing that reads as lag.
  void _applyCodeQuietly(int uid, String code) {
    final int index = messages.indexWhere((MessageSummary m) => m.uid == uid);
    if (index == -1 || messages[index].otp == code) return;
    messages[index] = messages[index].copyWith(otp: code);
    // The page is remembered once when the pass is done, not here: this used to
    // copy the whole page for every code found, which is O(messages × codes)
    // for one folder load.
  }

  Future<void> loadMore() async {
    final MailFolder? folder = selectedFolder;
    if (!_connected || folder == null || loadingMore || !hasMore) return;

    final int token = _folderToken;
    loadingMore = true;
    _notify();
    try {
      final List<int> next =
          _uids.skip(messages.length).take(_pageSize).toList();
      final List<MessageSummary> more =
          await _transport.fetchSummariesByUid(folder, next);
      if (token != _folderToken) return;
      messages = <MessageSummary>[...messages, ...more];
    } catch (error) {
      if (token != _folderToken) return;
      errorMessage = error.toString();
    } finally {
      if (token == _folderToken) {
        loadingMore = false;
        _notify();
      }
    }
  }

  Future<void> refreshMessages() async {
    final MailFolder? folder = selectedFolder;
    if (folder == null) return;
    final String? query = searchQuery;
    if (query != null) {
      await search(query);
    } else {
      await openFolder(folder, refresh: true);
    }
  }

  /// Searches sender and subject. An empty query returns to the plain listing.
  Future<void> search(String query) async {
    final MailFolder? folder = selectedFolder;
    final String trimmed = query.trim();
    if (!_connected || folder == null) return;

    if (trimmed.isEmpty) {
      searchQuery = null;
      await openFolder(folder);
      return;
    }

    final int token = ++_folderToken;
    searchQuery = trimmed;
    openMessage = null;
    openSummary = null;
    messages = <MessageSummary>[];
    loadingMessages = true;
    errorMessage = null;
    _notify();

    try {
      final List<MessageSummary> found =
          await _transport.search(folder, trimmed);
      if (token != _folderToken) return;
      messages = found;
    } catch (error) {
      if (token != _folderToken) return;
      errorMessage = error.toString();
    } finally {
      if (token == _folderToken) {
        loadingMessages = false;
        _notify();
      }
    }
  }

  void clearSearch() {
    final MailFolder? folder = selectedFolder;
    searchQuery = null;
    if (folder != null) unawaited(openFolder(folder));
  }

  Future<void> open(MessageSummary summary) async {
    if (summary.folderPath != null && summary.folderPath != selectedFolder?.path) {
      return;
    }
    clearSelection();
    if (!_connected) return;

    final String? folderPath = summary.folderPath ?? selectedFolder?.path;
    final int token = ++_messageToken;
    openSummary = summary;
    openMessage = null;
    loadingMessage = true;
    _notify();

    try {
      // The cache first, when it is on. A message read once opens without the
      // network, and the copy it opens from came off an encrypted disk.
      final FullMessage? cached = await _cachedBody(summary, folderPath);
      final FullMessage loaded = cached ?? await _transport.fetchMessage(summary);
      if (token != _messageToken) return; // a newer message won
      openMessage = loaded;
      // The only place the recipients of a message appear: a list row carries
      // the sender and nothing else.
      Contacts.observeRecipients(loaded);
      if (cached == null) unawaited(_rememberBody(summary, loaded, folderPath));
      if (_markAsRead) {
        // The count follows the row: opening an unread message is one less
        // waiting, whether or not the list behind it is on screen.
        if (!summary.isSeen) _adjustUnseen(folderPath, -1);
        // The open row too, not only the list behind it: "Mark as unread" reads
        // its state from here, and a stale copy would count the message back
        // only if it thought it had been read.
        openSummary = summary.copyWith(isSeen: true);
        _replace(summary.uid, openSummary!);
        // Set \Seen deliberately rather than as a side effect of reading, so
        // the row and the server agree. Best effort: a failure must not hide
        // the mail.
        unawaited(_markSeenQuietly(summary));
      }
    } catch (error) {
      if (token != _messageToken) return;
      errorMessage = error.toString();
    } finally {
      if (token == _messageToken) {
        loadingMessage = false;
        _notify();
      }
    }
  }

  /// The cached body for [summary], when caching is on and there is one.
  Future<FullMessage?> _cachedBody(
    MessageSummary summary,
    String? folderPath,
  ) async {
    final LocalStore? store = _store;
    if (store == null || folderPath == null) return null;
    if (!(_preferences?.cacheMessages ?? true)) return null;
    try {
      final Map<String, Object?>? record =
          await store.message(folderPath, summary.uid);
      return record == null ? null : FullMessage.fromCache(record);
    } catch (_) {
      // An unreadable cache is an absent one; fetch it instead.
      return null;
    }
  }

  /// Writes a fetched body to the encrypted cache.
  ///
  /// Best effort, and skipped for anything the cache cannot hand back whole: a
  /// message with attachments is left out rather than cached without them.
  Future<void> _rememberBody(
    MessageSummary summary,
    FullMessage message,
    String? folderPath,
  ) async {
    final LocalStore? store = _store;
    if (store == null || folderPath == null) return;
    if (!(_preferences?.cacheMessages ?? true)) return;
    if (!message.isCacheable) return;
    try {
      await store.saveMessage(folderPath, summary.uid, message.toCache());
    } catch (_) {
      // The message is on screen either way.
    }
  }

  Future<void> _markSeenQuietly(MessageSummary summary) async {
    try {
      await _transport.markSeen(summary);
    } catch (_) {
      // The message is readable either way.
    }
  }

  void closeMessage() {
    _messageToken++; // anything in flight for the old message is now stale
    openMessage = null;
    openSummary = null;
    _notify();
  }

  /// Deletes any row, not just the open one, so a swipe can call it.
  Future<void> delete(MessageSummary summary, {bool permanently = false}) =>
      _runOn(
        summary,
        () => _transport.deleteMessage(
          summary,
          trashPath: trashPath,
          permanently: permanently,
        ),
        remove: true,
        unseenDelta: summary.isSeen ? 0 : -1,
      );

  Future<void> deleteOpenMessage({bool permanently = false}) async {
    final MessageSummary? summary = openSummary;
    if (!_connected || summary == null) return;
    await delete(summary, permanently: permanently);
  }

  /// Puts a just-deleted message back where it was.
  ///
  /// Not the same as restore: restore means "out of the trash", this means
  /// "never mind", and it returns the message to the folder it was deleted
  /// from rather than to the inbox.
  Future<void> undoDelete(MessageSummary summary, String path) =>
      _runOn(
        summary,
        () => _transport.moveMessage(summary, path),
        // Back where it was, so an unread one is waiting again.
        unseenDelta: summary.isSeen ? 0 : 1,
      );

  /// True when the folder on screen is the trash.
  bool get inTrash => selectedFolder?.role == FolderRole.trash;

  /// Puts a message from the trash back in the inbox.
  ///
  /// IMAP has no "undo": a message in the trash is a message that was moved
  /// there, so getting it back means moving it again. When there is no inbox to
  /// move it to there is nothing honest to do but say so.
  Future<void> restore(MessageSummary summary) async {
    final String? path = _folderPathFor(FolderRole.inbox);
    if (path == null) {
      errorMessage = 'This account has no Inbox folder to restore into.';
      _notify();
      return;
    }
    await _runOn(summary, () => _transport.moveMessage(summary, path),
        remove: true, unseenDelta: summary.isSeen ? 0 : -1);
  }

  /// Empties the trash.
  ///
  /// This one does not come back: an expunged message is gone from the server,
  /// not moved. The caller asks first.
  Future<void> emptyTrash() async {
    if (!_connected) return;

    final String? path = trashPath;
    if (path == null) {
      errorMessage = 'This account has no Trash folder.';
      _notify();
      return;
    }

    MailFolder? trash;
    for (final MailFolder f in folders) {
      if (f.role == FolderRole.trash) {
        trash = f;
        break;
      }
    }
    if (trash == null) return;

    // Read the folder rather than trusting what is on screen: the list may be
    // filtered, and emptying the trash must empty the trash.
    loadingMessages = true;
    errorMessage = null;
    _notify();
    try {
      await _transport.selectFolder(trash);
      final List<int> uids = await _transport.listMessageUids(trash);
      for (final int uid in uids) {
        if (!_connected) break;
        await _transport.deleteMessage(
          MessageSummary(
            uid: uid,
            sequenceId: uid,
            subject: '',
            fromName: '',
            fromEmail: '',
            date: null,
            isSeen: true,
            isFlagged: false,
          ),
          trashPath: null,
          permanently: true,
        );
      }
    } catch (error) {
      errorMessage = 'Could not empty the trash.';
      debugPrint('Ace Mail: emptyTrash failed (${Redact.safe(error)})');
    } finally {
      loadingMessages = false;
      _notify();
    }

    // And then show it, so the folder is not left claiming to have messages.
    if (_connected) await openFolder(trash, refresh: true);
  }

  /// Moves a message out of the way. Needs an Archive folder to move it to.
  Future<void> archive(MessageSummary summary) async {
    final String? path = _folderPathFor(FolderRole.archive);
    if (path == null) {
      errorMessage = 'This account has no Archive folder.';
      _notify();
      return;
    }
    await _runOn(summary, () => _transport.moveMessage(summary, path),
        remove: true, unseenDelta: summary.isSeen ? 0 : -1);
  }

  /// Flips a message's read state from the list.
  Future<void> toggleRead(MessageSummary summary) async {
    final bool next = !summary.isSeen;
    await _runOn(
      summary,
      () => next
          ? _transport.markSeen(summary)
          : _transport.markUnread(summary),
      updated: summary.copyWith(isSeen: next),
      unseenDelta: next ? -1 : 1,
    );
  }

  /// Marks a message read from the list, and does nothing to one already read.
  ///
  /// Not `toggleRead`: a button that says "Mark as read" must not do the
  /// opposite to the messages that already are.
  Future<void> markRead(MessageSummary summary) async {
    if (summary.isSeen) return;
    await _runOn(
      summary,
      () => _transport.markSeen(summary),
      updated: summary.copyWith(isSeen: true),
      unseenDelta: -1,
    );
  }

  /// Flips a message's flag from the list.
  Future<void> toggleFlag(MessageSummary summary) async {
    final bool next = !summary.isFlagged;
    await _runOn(
      summary,
      () => _transport.setFlagged(summary, next),
      updated: summary.copyWith(isFlagged: next),
    );
  }

  /// Runs an action against one row and reconciles the list with the result.
  /// Either the row leaves, or it is replaced in place — never both, and never
  /// a silent no-op.
  Future<void> _runOn(
    MessageSummary summary,
    Future<void> Function() action, {
    MessageSummary? updated,
    bool remove = false,
    int unseenDelta = 0,
  }) async {
    if (!_connected) return;
    final String? actionFolderPath = summary.folderPath ?? selectedFolder?.path;
    if (actionFolderPath != null && selectedFolder?.path != actionFolderPath) {
      return;
    }
    try {
      await action();
      // A queued operation may finish after the user switched folders. Its UID
      // belongs to the old mailbox and must not mutate a same-numbered row here.
      if (actionFolderPath != null && selectedFolder?.path != actionFolderPath) {
        return;
      }
      // Only once the server has agreed. A count that moved on a command that
      // then failed would be a count that never comes back.
      _adjustUnseen(actionFolderPath, unseenDelta);
      if (remove) {
        messages =
            messages.where((MessageSummary m) => m.uid != summary.uid).toList();
        _uids = _uids.where((int uid) => uid != summary.uid).toList();
        if (openSummary?.uid == summary.uid) {
          openMessage = null;
          openSummary = null;
        }
      } else if (updated != null) {
        _replace(summary.uid, updated);
        if (openSummary?.uid == summary.uid) openSummary = updated;
      }
      _notify();
    } catch (error) {
      errorMessage = error.toString();
      _notify();
    }
  }

  /// Flips the message back to unread and leaves it open.
  Future<void> markOpenUnread() async {
    final MessageSummary? summary = openSummary;
    if (summary == null) return;
    final String? actionFolderPath = summary.folderPath ?? selectedFolder?.path;
    if (actionFolderPath != null && selectedFolder?.path != actionFolderPath) return;
    try {
      await _transport.markUnread(summary);
      if (actionFolderPath != null && selectedFolder?.path != actionFolderPath) return;
      // Guarded on the row's state: marking unread something that is already
      // unread must not count it twice.
      if (summary.isSeen) _adjustUnseen(actionFolderPath, 1);
      // The open row as well as the list: this is the state the next press of
      // this button reads, and a stale copy would count the message twice.
      openSummary = summary.copyWith(isSeen: false);
      _replace(summary.uid, openSummary!);
      _notify();
    } catch (error) {
      errorMessage = error.toString();
      _notify();
    }
  }

  Future<void> toggleOpenFlagged() async {
    final MessageSummary? summary = openSummary;
    if (summary == null) return;
    final bool next = !summary.isFlagged;
    final String? actionFolderPath = summary.folderPath ?? selectedFolder?.path;
    if (actionFolderPath != null && selectedFolder?.path != actionFolderPath) return;
    try {
      await _transport.setFlagged(summary, next);
      if (actionFolderPath != null && selectedFolder?.path != actionFolderPath) return;
      _replace(summary.uid, summary.copyWith(isFlagged: next));
      openSummary = summary.copyWith(isFlagged: next);
      _notify();
    } catch (error) {
      errorMessage = error.toString();
      _notify();
    }
  }

  Future<void> send({
    required String to,
    required String body,
    String cc = '',
    String bcc = '',
    String subject = '',
    List<File> attachments = const <File>[],
    String? inReplyTo,
    String? references,
  }) async {
    if (!_connected) throw const MailConnectionException('Not connected.');
    await _transport.send(
      to: to,
      body: body,
      cc: cc,
      bcc: bcc,
      subject: subject,
      password: await _secret(),
      attachments: attachments,
      inReplyTo: inReplyTo,
      references: references,
      // Only file a copy ourselves when the provider will not.
      sentPath: _filesSentItself.contains(account.domain) ? null : sentPath,
    );
  }

  void clearError() => errorMessage = null;

  void _replace(int uid, MessageSummary updated) {
    final int index = messages.indexWhere((MessageSummary m) => m.uid == uid);
    if (index == -1) return;
    messages = List<MessageSummary>.of(messages)..[index] = updated;
  }

  /// Never notify after disposal: listeners are gone and ChangeNotifier throws
  /// in debug builds.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _messageToken++;
    _folderToken++;
    if (_connected) unawaited(_transport.disconnect());
    _connected = false;
    super.dispose();
  }

  static T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
    for (final T item in items) {
      if (test(item)) return item;
    }
    return null;
  }
}
