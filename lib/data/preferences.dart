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
  ];

  final FlutterSecureStorage _storage;

  bool _showAvatars = false;
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
  bool _loadRemoteImages = false;
  AceAccent _accent = AceAccent.orange;

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
