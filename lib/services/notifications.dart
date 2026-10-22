import 'package:flutter/foundation.dart';
import '../util/redact.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// One place that knows how to put a notification on the screen.
///
/// Everything here is best-effort: a device that refuses notifications, or a
/// platform without them, must not stop the app from running. Every call is
/// guarded and every failure is swallowed with a debug note, because the
/// alternative is a mail client that will not start because of a badge.
abstract final class AceNotifications {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _ready = false;

  /// The Android channel. One channel, because the app has one kind of
  /// notification, and a channel is a user-facing setting — a list of them
  /// would be a list of decisions nobody wants to make.
  static const AndroidNotificationDetails _android =
      AndroidNotificationDetails(
    'new_mail',
    'New mail',
    channelDescription: 'Told when new mail arrives in an account you added.',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    // Grouped, so ten messages are one line rather than ten.
    groupKey: 'ace_mail_new',
    // The text is only on the lock screen when the setting says so; the
    // *visibility* is private either way, which also keeps the notification off
    // the lock screen on a device that has been told to hide sensitive content.
    visibility: NotificationVisibility.private,
  );

  static Future<void> initialise() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: // The app's own mark, flattened to one colour. Android tints a
          // notification icon, so anything with colour in it comes out as a
          // blob; this is the envelope as a silhouette.
          AndroidInitializationSettings('@drawable/ic_notification'),
        ),
      );
      _ready = true;
    } catch (error) {
      debugPrint('Ace Mail: notifications unavailable (${Redact.safe(error)})');
    }
  }

  /// Asks the platform for permission. Called when the setting is turned on,
  /// not at launch: a permission prompt before the user has asked for anything
  /// is a prompt they refuse.
  static Future<bool> requestPermission() async {
    await initialise();
    try {
      final AndroidFlutterLocalNotificationsPlugin? android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return true;
      return await android.requestNotificationsPermission() ?? false;
    } catch (error) {
      debugPrint('Ace Mail: could not ask for permission (${Redact.safe(error)})');
      return false;
    }
  }

  /// Says [count] messages arrived in [account].
  ///
  /// [privatePreviews] drops the sender and the subject. A notification is read
  /// by whoever is holding the phone — on a locked screen that is anyone in the
  /// room — so the default is to say that there is mail and not what it says.
  static Future<void> newMail({
    required String account,
    required int count,
    required String? subject,
    bool privatePreviews = true,
  }) async {
    if (!_ready) return;
    try {
      final String title = privatePreviews
          ? 'New mail'
          : (count == 1 ? 'New message' : '$count new messages');
      final String body = privatePreviews
          ? 'Open Ace Mail to read it.'
          : (subject == null || subject.isEmpty
              ? account
              : '$account — $subject');

      await _plugin.show(
        id: account.hashCode,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: _android),
      );
    } catch (error) {
      debugPrint('Ace Mail: could not notify (${Redact.safe(error)})');
    }
  }

  /// Clears anything still showing for an account.
  static Future<void> clear(String account) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: account.hashCode);
    } catch (_) {
      // Nothing to clear.
    }
  }
}
