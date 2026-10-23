import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'util/redact.dart';
import 'data/app_info.dart';
import 'data/local_store.dart';
import 'data/preferences.dart';
import 'services/launcher_icon.dart';
import 'services/local_avatars.dart';
import 'services/notification_setup.dart';
import 'state/mail_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A little more room for decoded images. The default is sized for a phone
  // showing a handful; a mail reader scrolls through many, and re-decoding the
  // same attachment on every pass is the kind of cost that shows up as jank.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 80 << 20;

  // The encrypted local store: the draft in progress, and the messages already
  // read. Best effort — a device that will not hand over a directory must not
  // stop the app starting. Without it nothing is cached, which is a working
  // mail client, just a slower one.
  // The pictures people chose for their own addresses. Beside the store
  // because it needs the same directory, and best effort for the same reason.
  await LocalAvatars.init();

  LocalStore? localStore;
  try {
    localStore = await LocalStore.open();
  } catch (error) {
    debugPrint('Ace Mail: no local cache (${Redact.safe(error)})');
  }

  // Created here rather than in a provider callback so the controller can hold
  // the same instance — the reading settings live on it.
  final Preferences preferences = Preferences();
  final MailController controller =
      MailController(preferences: preferences, localStore: localStore);

  // Read the keychain and the settings before the first frame, so the app opens
  // straight into the mailbox or the sign-in screen. There is no intermediate
  // loading screen; the native launch window covers the moment this takes.
  await Future.wait<void>(<Future<void>>[
    preferences.load(),
    controller.restore(),
    AppInfo.load(),
  ]);

  // The launcher icon wears the accent. Applied on every start rather than only
  // when the setting changes, because the alias that carries it can be reset by
  // an install over the top of an old build.
  unawaited(LauncherIcon.apply(preferences.accent));

  // Registered before the first frame, so a scheduled check that fires while
  // the app is closed has somewhere to land. Nothing is scheduled unless the
  // setting says so.
  await NotificationSetup.initialise();
  if (preferences.notifyNewMail) {
    await NotificationSetup.apply(enabled: true);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<Preferences>.value(value: preferences),
        ChangeNotifierProvider<MailController>.value(value: controller),
        Provider<LocalStore?>.value(value: localStore),
      ],
      child: const AceMailApp(),
    ),
  );
}
