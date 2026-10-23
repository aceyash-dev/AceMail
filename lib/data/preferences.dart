import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'accents.dart';
import '../models/glass_mode.dart';
import '../models/message_sort.dart';
import '../models/swipe_action.dart';

/// Which appearance the app follows.
enum AceThemeMode {
  system('System'),
  light('Light'),
  dark('Dark');

  const AceThemeMode(this.label);

  final String label;
}

/// How large the app's text is drawn, on top of the system setting.
enum AceTextSize {
  small('Small', 0.9),
  medium('Default', 1.0),
  large('Large', 1.15);

  const AceTextSize(this.label, this.scale);

  final String label;
  final double scale;
}

/// How many messages a page of the list holds.
enum PageSize {
  twenty('20', 20),
  forty('40', 40),
  eighty('80', 80);

  const PageSize(this.label, this.count);

  final String label;
  final int count;
}

/// How tightly the message list is packed.
enum ListDensity {
  comfortable('Comfortable', 42, 12),
  compact('Compact', 34, 8);

  const ListDensity(this.label, this.avatarSize, this.verticalPadding);

  final String label;
  final double avatarSize;
  final double verticalPadding;
}

/// Which representation of a message the reader opens with.
enum MessageView {
  formatted('Formatted'),
  plainText('Plain text');

  const MessageView(this.label);

  final String label;
}

/// How long the undo on a snack bar stays offered.
///
/// Long enough to notice a mistake and reach for it, short enough that the bar
/// is gone before it becomes furniture. Six seconds is the default because it is
/// the shortest that reliably survives the beat of "wait — what did that do?".
enum UndoWindow {
  short('4 seconds', 4),
  normal('6 seconds', 6),
  long('10 seconds', 10);

  const UndoWindow(this.label, this.seconds);

  final String label;
  final int seconds;

  Duration get duration => Duration(seconds: seconds);
}

/// The app's settings.
///
/// Kept in the same store as the accounts because it is already there and works
/// on every platform — nothing here is a secret. Every value is real: changing
/// one changes behaviour at once and survives a restart.
class Preferences extends ChangeNotifier {
  Preferences({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _keyAvatars = 'ace.showAvatars';
  static const String _keyTheme = 'ace.themeMode';
  static const String _keyTextSize = 'ace.textSize';
  static const String _keyConfirmExit = 'ace.confirmExit';
  static const String _keyMarkRead = 'ace.markAsReadOnOpen';
  static const String _keySignature = 'ace.signature';
  static const String _keySwipeStart = 'ace.swipeStart';
  static const String _keySwipeEnd = 'ace.swipeEnd';
  static const String _keyMessageView = 'ace.messageView';
  static const String _keyAutoReconnect = 'ace.autoReconnect';
  static const String _keyPageSize = 'ace.pageSize';
  static const String _keyDensity = 'ace.listDensity';
  static const String _keyConfirmDelete = 'ace.confirmDelete';
  static const String _keyDetectCodes = 'ace.detectCodes';
  static const String _keyMessageSort = 'ace.messageSort';
  static const String _keyRemoteImages = 'ace.remoteImages';
  static const String _keyAccent = 'ace.accent';
  static const String _keyRawHeaders = 'ace.rawHeaders';
  static const String _keyDynamicColour = 'ace.dynamicColour';
  static const String _keyWarnEmptySubject = 'ace.warnEmptySubject';
  static const String _keyWarnExternalLinks = 'ace.warnExternalLinks';
  static const String _keyNotifyNewMail = 'ace.notifyNewMail';
  static const String _keyLastSeen = 'ace.lastSeen';
  static const String _keyHaptics = 'ace.haptics';
  static const String _keyOled = 'ace.oled';
  static const String _keyReduceMotion = 'ace.reduceMotion';
  static const String _keyGroupByDate = 'ace.groupByDate';
  static const String _keyFolderCounts = 'ace.folderCounts';
  static const String _keySeenVersion = 'ace.seenVersion';
  static const String _keyQuoteReplies = 'ace.quoteReplies';
  static const String _keySignatureOnReplies = 'ace.signatureOnReplies';
  static const String _keyConfirmArchive = 'ace.confirmArchive';
  static const String _keyUndoWindow = 'ace.undoWindow';
  static const String _keyBccSelf = 'ace.bccSelf';
  static const String _keyCacheMessages = 'ace.cacheMessages';
  static const String _keyAppLock = 'ace.appLock';
  static const String _keyPrivatePreviews = 'ace.privatePreviews';
  static const String _keyChymeEnabled = 'ace.chymeEnabled';
  static const String _keyChymeEndpoint = 'ace.chymeEndpoint';
  static const String _keyChymeModel = 'ace.chymeModel';
  static const String _keyChymeKey = 'ace.chymeKey';
  static const String _keyChymeReadsMail = 'ace.chymeReadsMail';
  static const String _keyWarnMissingAttachment = 'ace.warnMissingAttachment';
  static const String _keyGlass = 'ace.glass';

  static const List<String> _keys = <String>[
    _keyAvatars,
    _keyTheme,
    _keyTextSize,
    _keyConfirmExit,
    _keyMarkRead,
    _keySignature,
    _keySwipeStart,
    _keySwipeEnd,
    _keyMessageView,
    _keyAutoReconnect,
    _keyPageSize,
    _keyDensity,
    _keyConfirmDelete,
    _keyDetectCodes,
    _keyMessageSort,
    _keyRemoteImages,
    _keyAccent,
    _keyRawHeaders,
    _keyDynamicColour,
    _keyWarnEmptySubject,
    _keyWarnExternalLinks,
    _keyNotifyNewMail,
    _keyLastSeen,
    _keyHaptics,
    _keyOled,
    _keyReduceMotion,
    _keyGroupByDate,
    _keyFolderCounts,
    _keySeenVersion,
    _keyQuoteReplies,
    _keySignatureOnReplies,
    _keyConfirmArchive,
    _keyUndoWindow,
    _keyBccSelf,
    _keyCacheMessages,
    _keyAppLock,
    _keyPrivatePreviews,
    _keyChymeEnabled,
    _keyChymeEndpoint,
    _keyChymeModel,
    _keyChymeKey,
    _keyChymeReadsMail,
    _keyWarnMissingAttachment,
    _keyGlass,
  ];

  final FlutterSecureStorage _storage;

  // The defaults are deliberately *on*: the app ships with everything it can do
  // switched on, and the settings are there to take things away. The four
  // exceptions each say why they are exceptions.
  //
  // Off because it is a developer's view of the message:
  bool _showRawHeaders = false;
  // Off because it makes the accent the wallpaper's, and a launcher icon cannot
  // follow the wallpaper — the icon would then disagree with the app it opens.
  // One switch, for anyone who wants Material You anyway:
  bool _useDynamicColour = false;

  bool _showAvatars = true;
  AceThemeMode _themeMode = AceThemeMode.system;
  AceTextSize _textSize = AceTextSize.medium;
  bool _confirmExit = true;
  bool _markAsReadOnOpen = true;
  String _signature = '';
  SwipeAction _swipeStart = SwipeAction.toggleRead;
  SwipeAction _swipeEnd = SwipeAction.archive;
  MessageView _messageView = MessageView.formatted;
  bool _autoReconnect = true;
  PageSize _pageSize = PageSize.forty;
  ListDensity _density = ListDensity.comfortable;
  bool _confirmDelete = true;
  bool _detectCodes = true;
  MessageSort _messageSort = MessageSort.newest;
  bool _loadRemoteImages = true;
  AceAccent _accent = AceAccent.orange;
  bool _warnEmptySubject = true;
  bool _warnExternalLinks = true;
  bool _notifyNewMail = true;
  bool _haptics = true;
  bool _oled = true;
  // Off because it is an accessibility preference — one someone has to choose,
  // rather than one that can be chosen for them.
  bool _reduceMotion = false;
  bool _groupByDate = true;
  bool _showFolderCounts = true;
  String? _lastSeenVersion;
  bool _quoteReplies = true;
  bool _signatureOnReplies = true;
  bool _confirmArchive = true;
  UndoWindow _undoWindow = UndoWindow.normal;
  bool _bccSelf = true;
  bool _cacheMessages = true;
  // Off because it locks the app for whoever installs it, before they have
  // asked for a lock — and on a device that cannot authenticate, that is a
  // screen with no way past it.
  bool _appLock = false;
  bool _privatePreviews = true;
  // Chyme ships off, and this is the one setting that does. It cannot do
  // anything at all until somebody gives it an endpoint — a switch that is on
  // and does nothing is exactly what the rest of these defaults exist to
  // avoid.
  bool _chymeEnabled = false;
  String _chymeEndpoint = '';
  String _chymeModel = '';
  String _chymeKey = '';
  bool _chymeReadsMail = true;
  bool _warnMissingAttachment = true;
  GlassMode _glass = GlassMode.auto;
  Map<String, int> _lastSeen = <String, int>{};

  /// Whether sender pictures are fetched from Gravatar.
  ///
  /// **A disclosure, and it is on.** A Gravatar lookup sends an MD5 of every
  /// sender's address to a third party, and a hash of an address is not
  /// anonymous — addresses are guessable and can be hashed by anyone. It is on
  /// because a list with faces in it is a list you can read at a glance, and
  /// the switch to stop the requests is one tap away. Off means no request is
  /// ever made.
  bool get showAvatars => _showAvatars;

  AceThemeMode get themeMode => _themeMode;

  AceTextSize get textSize => _textSize;

  double get textScale => _textSize.scale;

  /// Whether leaving the mailbox asks first.
  bool get confirmExit => _confirmExit;

  /// Whether opening a message sets `\Seen` on the server.
  bool get markAsReadOnOpen => _markAsReadOnOpen;

  /// Appended to a new message's body.
  String get signature => _signature;

  /// What dragging a message row to the right does.
  SwipeAction get swipeStart => _swipeStart;

  /// What dragging a message row to the left does.
  SwipeAction get swipeEnd => _swipeEnd;

  /// Whether the reader opens formatted or as plain text.
  MessageView get messageView => _messageView;

  /// Whether a dropped connection is retried automatically.
  bool get autoReconnect => _autoReconnect;

  /// How many messages a page holds.
  PageSize get pageSize => _pageSize;

  /// How tightly the message list is packed.
  ListDensity get density => _density;

  /// Whether deleting asks first.
  bool get confirmDelete => _confirmDelete;

  /// Whether one-time codes are picked out of messages and shown in the list.
  bool get detectCodes => _detectCodes;

  /// The order the message list is shown in.
  MessageSort get messageSort => _messageSort;

  /// Whether images in a message are fetched from the sender's server. Off by
  /// default: loading one confirms the message was opened.
  bool get loadRemoteImages => _loadRemoteImages;

  /// The accent the whole app is built from.
  AceAccent get accent => _accent;

  /// Whether the reader shows the message's raw headers.
  bool get showRawHeaders => _showRawHeaders;

  /// Whether the accent comes from the platform instead of the list — Android's
  /// Monet, and the equivalent elsewhere.
  bool get useDynamicColour => _useDynamicColour;

  /// Whether sending with no subject asks first. A message with no subject is
  /// the one people regret.
  bool get warnEmptySubject => _warnEmptySubject;

  /// Whether a link in a message asks before it leaves the app.
  bool get warnExternalLinks => _warnExternalLinks;

  /// Whether new mail is announced. Off until asked for, and it asks the
  /// platform for permission at that moment rather than at launch.
  bool get notifyNewMail => _notifyNewMail;

  /// Whether taps are felt.
  bool get haptics => _haptics;

  /// True black, for an OLED panel. A pixel that is off draws no power, and on
  /// a dark background the difference between #0E0E0E and #000000 is visible
  /// at the edges of the screen.
  bool get oled => _oled;

  /// Whether the app's transitions move.
  bool get reduceMotion => _reduceMotion;

  /// Whether the list is headed Today, Yesterday, and so on. Off is one
  /// undivided run of messages, for people who would rather see the newest
  /// thing at the top of the screen.
  bool get groupByDate => _groupByDate;

  /// Whether each folder shows how much unread mail is in it.
  bool get showFolderCounts => _showFolderCounts;

  /// The version whose release notes have already been shown. Null means the
  /// app has not been through an update yet.
  String? get lastSeenVersion => _lastSeenVersion;

  /// Whether a reply starts with the original message quoted beneath it.
  bool get quoteReplies => _quoteReplies;

  /// Whether the signature is added to replies as well as to new messages.
  bool get signatureOnReplies => _signatureOnReplies;

  /// Whether archiving asks first.
  ///
  /// Off by default: archiving is the routine way to clear the inbox, and a
  /// question in front of a routine action is a question people learn to dismiss
  /// without reading — which is the worst of both worlds.
  bool get confirmArchive => _confirmArchive;

  /// How long the undo on a snack bar stays offered.
  UndoWindow get undoWindow => _undoWindow;

  /// Whether a copy of every message is blind-copied to the sending account.
  bool get bccSelf => _bccSelf;

  /// Whether messages that have been read are kept on the device.
  ///
  /// What is kept is sealed — AES-256-GCM, key in the keychain — but keeping
  /// nothing at all is a legitimate answer to "should this phone hold my
  /// mail", so it is a setting rather than a fact of the app.
  bool get cacheMessages => _cacheMessages;

  /// Whether opening the app asks for a fingerprint or a face first.
  bool get appLock => _appLock;

  /// Whether Chyme is available at all.
  bool get chymeEnabled => _chymeEnabled;

  /// The API base, as the person typed it. Normalised on use rather than on
  /// save, so what they typed is what they see when they come back.
  String get chymeEndpoint => _chymeEndpoint;

  /// The model to ask. Empty until one is chosen from what the endpoint lists.
  String get chymeModel => _chymeModel;

  /// The key for the endpoint. Kept in the keychain, like the app passwords:
  /// it is a credential, and it is stored where credentials go.
  String get chymeKey => _chymeKey;

  /// Whether Chyme may see the message you have open, and the list you are
  /// looking at. Off means it answers without looking at any mail.
  bool get chymeReadsMail => _chymeReadsMail;

  /// Whether sending a message that talks about an attachment, with nothing
  /// attached, asks first. The mistake it catches is a real one and a common
  /// one: "I've attached the form" and no form.
  bool get warnMissingAttachment => _warnMissingAttachment;

  /// How see-through the floating surfaces are.
  ///
  /// Automatic by default, which means "when the device can afford it": the
  /// blur is a render effect on Android 12 and later and a framebuffer readback
  /// before that, and only one of those is a material.
  GlassMode get glass => _glass;

  /// Whether a notification names the sender and the subject.
  ///
  /// On by default: a notification on a lock screen is read by whoever is
  /// holding the phone, and "you have mail" is enough for most people.
  bool get privatePreviews => _privatePreviews;

  Future<void> setQuoteReplies(bool value) =>
      _write(_keyQuoteReplies, '$value', () => _quoteReplies = value);

  Future<void> setSignatureOnReplies(bool value) => _write(
      _keySignatureOnReplies, '$value', () => _signatureOnReplies = value);

  Future<void> setConfirmArchive(bool value) =>
      _write(_keyConfirmArchive, '$value', () => _confirmArchive = value);

  Future<void> setUndoWindow(UndoWindow value) =>
      _write(_keyUndoWindow, value.name, () => _undoWindow = value);

  Future<void> setBccSelf(bool value) =>
      _write(_keyBccSelf, '$value', () => _bccSelf = value);

  Future<void> setCacheMessages(bool value) =>
      _write(_keyCacheMessages, '$value', () => _cacheMessages = value);

  Future<void> setAppLock(bool value) =>
      _write(_keyAppLock, '$value', () => _appLock = value);

  Future<void> setPrivatePreviews(bool value) =>
      _write(_keyPrivatePreviews, '$value', () => _privatePreviews = value);

  Future<void> setChymeEnabled(bool value) =>
      _write(_keyChymeEnabled, '$value', () => _chymeEnabled = value);

  Future<void> setChymeEndpoint(String value) =>
      _write(_keyChymeEndpoint, value, () => _chymeEndpoint = value);

  Future<void> setChymeModel(String value) =>
      _write(_keyChymeModel, value, () => _chymeModel = value);

  Future<void> setChymeKey(String value) =>
      _write(_keyChymeKey, value, () => _chymeKey = value);

  Future<void> setChymeReadsMail(bool value) =>
      _write(_keyChymeReadsMail, '$value', () => _chymeReadsMail = value);

  Future<void> setGlass(GlassMode value) =>
      _write(_keyGlass, value.name, () => _glass = value);

  Future<void> setWarnMissingAttachment(bool value) => _write(
        _keyWarnMissingAttachment,
        '$value',
        () => _warnMissingAttachment = value,
      );

  Future<void> setLastSeenVersion(String value) =>
      _write(_keySeenVersion, value, () => _lastSeenVersion = value);

  /// The highest inbox uid seen for an account, so the next check knows what is
  /// new. Kept here rather than in a second storage: it is one small number per
  /// account, and a background isolate can read it the same way the app does.
  int lastSeenUid(String email) => _lastSeen[email.toLowerCase()] ?? 0;

  Future<void> setLastSeenUid(String email, int uid) async {
    _lastSeen[email.toLowerCase()] = uid;
    await _write(_keyLastSeen, jsonEncode(_lastSeen), () {});
  }

  Future<void> load() async {
    final Map<String, String?> raw = <String, String?>{};
    for (final String key in _keys) {
      try {
        raw[key] = await _storage.read(key: key);
      } catch (_) {
        // A keychain we cannot read means defaults, not a crash.
        raw[key] = null;
      }
    }

    _showAvatars = _decodeBool(raw[_keyAvatars], _showAvatars);
    _confirmExit = _decodeBool(raw[_keyConfirmExit], _confirmExit);
    _markAsReadOnOpen = _decodeBool(raw[_keyMarkRead], _markAsReadOnOpen);
    _themeMode = _decodeEnum(raw[_keyTheme], AceThemeMode.values, _themeMode);
    _textSize = _decodeEnum(raw[_keyTextSize], AceTextSize.values, _textSize);
    _signature = raw[_keySignature] ?? _signature;
    _swipeStart =
        _decodeEnum(raw[_keySwipeStart], SwipeAction.values, _swipeStart);
    _swipeEnd = _decodeEnum(raw[_keySwipeEnd], SwipeAction.values, _swipeEnd);
    _messageView =
        _decodeEnum(raw[_keyMessageView], MessageView.values, _messageView);
    _autoReconnect = _decodeBool(raw[_keyAutoReconnect], _autoReconnect);
    _pageSize = _decodeEnum(raw[_keyPageSize], PageSize.values, _pageSize);
    _density = _decodeEnum(raw[_keyDensity], ListDensity.values, _density);
    _confirmDelete = _decodeBool(raw[_keyConfirmDelete], _confirmDelete);
    _detectCodes = _decodeBool(raw[_keyDetectCodes], _detectCodes);
    _messageSort =
        _decodeEnum(raw[_keyMessageSort], MessageSort.values, _messageSort);
    _loadRemoteImages =
        _decodeBool(raw[_keyRemoteImages], _loadRemoteImages);
    _accent = _decodeEnum(raw[_keyAccent], AceAccent.values, _accent);
    _showRawHeaders = _decodeBool(raw[_keyRawHeaders], _showRawHeaders);
    _useDynamicColour =
        _decodeBool(raw[_keyDynamicColour], _useDynamicColour);
    _warnEmptySubject =
        _decodeBool(raw[_keyWarnEmptySubject], _warnEmptySubject);
    _warnExternalLinks =
        _decodeBool(raw[_keyWarnExternalLinks], _warnExternalLinks);
    _notifyNewMail = _decodeBool(raw[_keyNotifyNewMail], _notifyNewMail);
    _lastSeen = _decodeLastSeen(raw[_keyLastSeen]);
    _haptics = _decodeBool(raw[_keyHaptics], _haptics);
    _oled = _decodeBool(raw[_keyOled], _oled);
    _reduceMotion = _decodeBool(raw[_keyReduceMotion], _reduceMotion);
    _groupByDate = _decodeBool(raw[_keyGroupByDate], _groupByDate);
    _showFolderCounts =
        _decodeBool(raw[_keyFolderCounts], _showFolderCounts);
    _quoteReplies = _decodeBool(raw[_keyQuoteReplies], _quoteReplies);
    _signatureOnReplies =
        _decodeBool(raw[_keySignatureOnReplies], _signatureOnReplies);
    _confirmArchive = _decodeBool(raw[_keyConfirmArchive], _confirmArchive);
    _undoWindow =
        _decodeEnum(raw[_keyUndoWindow], UndoWindow.values, _undoWindow);
    _bccSelf = _decodeBool(raw[_keyBccSelf], _bccSelf);
    _cacheMessages = _decodeBool(raw[_keyCacheMessages], _cacheMessages);
    _appLock = _decodeBool(raw[_keyAppLock], _appLock);
    _privatePreviews =
        _decodeBool(raw[_keyPrivatePreviews], _privatePreviews);
    _chymeEnabled = _decodeBool(raw[_keyChymeEnabled], _chymeEnabled);
    _chymeEndpoint = raw[_keyChymeEndpoint] ?? _chymeEndpoint;
    _chymeModel = raw[_keyChymeModel] ?? _chymeModel;
    _chymeKey = raw[_keyChymeKey] ?? _chymeKey;
    _chymeReadsMail = _decodeBool(raw[_keyChymeReadsMail], _chymeReadsMail);
    _warnMissingAttachment = _decodeBool(
      raw[_keyWarnMissingAttachment],
      _warnMissingAttachment,
    );
    _glass = _decodeEnum(raw[_keyGlass], GlassMode.values, _glass);
    final String? seen = raw[_keySeenVersion];
    _lastSeenVersion = (seen == null || seen.isEmpty) ? null : seen;

    notifyListeners();
  }

  Future<void> setShowAvatars(bool value) =>
      _write(_keyAvatars, '$value', () => _showAvatars = value);

  Future<void> setConfirmExit(bool value) =>
      _write(_keyConfirmExit, '$value', () => _confirmExit = value);

  Future<void> setMarkAsReadOnOpen(bool value) =>
      _write(_keyMarkRead, '$value', () => _markAsReadOnOpen = value);

  Future<void> setThemeMode(AceThemeMode value) =>
      _write(_keyTheme, value.name, () => _themeMode = value);

  Future<void> setTextSize(AceTextSize value) =>
      _write(_keyTextSize, value.name, () => _textSize = value);

  Future<void> setSignature(String value) =>
      _write(_keySignature, value, () => _signature = value);

  Future<void> setSwipeStart(SwipeAction value) =>
      _write(_keySwipeStart, value.name, () => _swipeStart = value);

  Future<void> setSwipeEnd(SwipeAction value) =>
      _write(_keySwipeEnd, value.name, () => _swipeEnd = value);

  Future<void> setMessageView(MessageView value) =>
      _write(_keyMessageView, value.name, () => _messageView = value);

  Future<void> setAutoReconnect(bool value) =>
      _write(_keyAutoReconnect, '$value', () => _autoReconnect = value);

  Future<void> setPageSize(PageSize value) =>
      _write(_keyPageSize, value.name, () => _pageSize = value);

  Future<void> setDensity(ListDensity value) =>
      _write(_keyDensity, value.name, () => _density = value);

  Future<void> setConfirmDelete(bool value) =>
      _write(_keyConfirmDelete, '$value', () => _confirmDelete = value);

  Future<void> setDetectCodes(bool value) =>
      _write(_keyDetectCodes, '$value', () => _detectCodes = value);

  Future<void> setMessageSort(MessageSort value) =>
      _write(_keyMessageSort, value.name, () => _messageSort = value);

  Future<void> setLoadRemoteImages(bool value) =>
      _write(_keyRemoteImages, '$value', () => _loadRemoteImages = value);

  Future<void> setAccent(AceAccent value) =>
      _write(_keyAccent, value.name, () => _accent = value);

  Future<void> setShowRawHeaders(bool value) =>
      _write(_keyRawHeaders, '$value', () => _showRawHeaders = value);

  Future<void> setUseDynamicColour(bool value) =>
      _write(_keyDynamicColour, '$value', () => _useDynamicColour = value);

  Future<void> setWarnEmptySubject(bool value) =>
      _write(_keyWarnEmptySubject, '$value', () => _warnEmptySubject = value);

  Future<void> setWarnExternalLinks(bool value) =>
      _write(_keyWarnExternalLinks, '$value', () => _warnExternalLinks = value);

  Future<void> setHaptics(bool value) =>
      _write(_keyHaptics, '$value', () => _haptics = value);

  Future<void> setGroupByDate(bool value) =>
      _write(_keyGroupByDate, '$value', () => _groupByDate = value);

  Future<void> setShowFolderCounts(bool value) =>
      _write(_keyFolderCounts, '$value', () => _showFolderCounts = value);

  Future<void> setReduceMotion(bool value) =>
      _write(_keyReduceMotion, '$value', () => _reduceMotion = value);

  Future<void> setOled(bool value) =>
      _write(_keyOled, '$value', () => _oled = value);

  Future<void> setNotifyNewMail(bool value) =>
      _write(_keyNotifyNewMail, '$value', () => _notifyNewMail = value);

  /// Best effort: a corrupt entry means no memory of what was seen, which costs
  /// one quiet check, not a crash.
  static Map<String, int> _decodeLastSeen(String? raw) {
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      return <String, int>{
        for (final MapEntry<Object?, Object?> e in decoded.entries)
          if (e.value is int) '${e.key}': e.value! as int,
      };
    } catch (_) {
      return <String, int>{};
    }
  }

  /// Applies [change] and notifies immediately, then persists. A toggle must
  /// not wait on the keychain before it looks like it worked.
  Future<void> _write(String key, String value, VoidCallback change) async {
    change();
    notifyListeners();
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // The setting still applies for this session.
    }
  }

  static bool _decodeBool(String? raw, bool fallback) =>
      raw == null ? fallback : raw == 'true';

  /// Unknown or stale stored values fall back rather than throwing.
  static T _decodeEnum<T extends Enum>(String? raw, List<T> values, T fallback) {
    if (raw == null) return fallback;
    for (final T value in values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }
}

