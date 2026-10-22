import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'mail_check.dart';
import 'notifications.dart';

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
      debugPrint('Ace Mail: background checks unavailable ($error)');
    }
    await AceNotifications.initialise();
  }

  /// Turns the background check on or off, asking for permission on the way in.
  ///
  /// Returns whether it ended up on, so the settings switch can tell the truth
  /// rather than showing a state that did not happen.
  static Future<bool> apply({required bool enabled}) async {
    await initialise();

    if (!enabled) {
      try {
        await Workmanager().cancelByUniqueName(kMailCheckTask);
      } catch (error) {
        debugPrint('Ace Mail: could not cancel the check ($error)');
      }
      return false;
    }

    final bool allowed = await AceNotifications.requestPermission();
    if (!allowed) return false;

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
      debugPrint('Ace Mail: could not schedule the check ($error)');
      return false;
    }
  }
}
