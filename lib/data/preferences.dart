import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'accents.dart';
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
  ];

  final FlutterSecureStorage _storage;

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
  bool _showRawHeaders = false;
  bool _useDynamicColour = false;
  bool _warnEmptySubject = true;
  bool _warnExternalLinks = true;
  bool _notifyNewMail = false;
  bool _haptics = true;
  bool _oled = false;
  bool _reduceMotion = false;
  Map<String, int> _lastSeen = <String, int>{};

  /// Whether sender pictures are fetched from Gravatar.
  ///
  /// **Off by default, and deliberately so.** A Gravatar lookup sends an MD5 of
  /// every sender's address to a third party. A hash of an address is not
  /// anonymous — addresses are guessable and can be hashed by anyone — so this
  /// is a disclosure the user opts into. When it is off, no request is made.
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
