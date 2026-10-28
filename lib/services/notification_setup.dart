import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'mail_check.dart';
import 'notifications.dart';
import '../util/redact.dart';

/// Starts, stops and drives the background mail check.
///
/// One place, because the pieces have to agree: WorkManager has to be
/// initialised before anything can be registered, the permission has to be
/// granted before a notification can be posted, and the task has to be
/// cancelled as well as registered or turning the setting off does nothing.
abstract final class NotificationSetup {
  /// How often the background check runs.
  ///
  /// Fifteen minutes is Android's floor for periodic work — anything shorter is
  /// silently rounded up, so asking for less would be a lie in the code.
  static const Duration interval = Duration(minutes: 15);

  static bool _initialised = false;

  static Future<void> initialise() async {
    if (_initialised) return;
    try {
      await Workmanager().initialize(mailCheckDispatcher);
      _initialised = true;
    } catch (error) {
      debugPrint('Ace Mail: background checks unavailable (${Redact.safe(error)})');
    }
    await AceNotifications.initialise();
  }

  /// Turns the background check on or off.
  ///
  /// Scheduling and permission are two different questions, and this used to
  /// treat them as one: a refused permission returned false and the task was
  /// never registered at all — so the check that also sends scheduled mail and
  /// keeps the badge honest stopped happening because a *notification* prompt
  /// was declined. It now schedules regardless, and asks for permission only
  /// when [askPermission] says so (the settings switch), reporting what the
  /// platform actually allows rather than what was hoped for.
  static Future<bool> apply({
    required bool enabled,
    bool askPermission = false,
  }) async {
    await initialise();

    if (!enabled) {
      try {
        await Workmanager().cancelByUniqueName(kMailCheckTask);
      } catch (error) {
        debugPrint('Ace Mail: could not cancel the check (${Redact.safe(error)})');
      }
      return false;
    }

    if (askPermission) await AceNotifications.requestPermission();

    try {
      await Workmanager().registerPeriodicTask(
        kMailCheckTask,
        kMailCheckTask,
        frequency: interval,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
      return true;
    } catch (error) {
      debugPrint('Ace Mail: could not schedule the check (${Redact.safe(error)})');
      return false;
    }
  }
}
