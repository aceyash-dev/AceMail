import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/app_info.dart';
import 'data/preferences.dart';
import 'state/mail_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Created here rather than in a provider callback so the controller can hold
  // the same instance — the reading settings live on it.
  final Preferences preferences = Preferences();
  final MailController controller = MailController(preferences: preferences);

  // Read the keychain and the settings before the first frame, so the app opens
  // straight into the mailbox or the sign-in screen. There is no intermediate
  // loading screen; the native launch window covers the moment this takes.
  await Future.wait<void>(<Future<void>>[
    preferences.load(),
    controller.restore(),
    AppInfo.load(),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<Preferences>.value(value: preferences),
        ChangeNotifierProvider<MailController>.value(value: controller),
      ],
      child: const AceMailApp(),
    ),
  );
}
