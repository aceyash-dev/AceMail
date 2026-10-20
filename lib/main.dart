import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/preferences.dart';
import 'state/mail_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Created here rather than in a provider callback so the controller can hold
  // the same instance — the reading settings live on it.
  final Preferences preferences = Preferences();
  unawaited(preferences.load());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<Preferences>.value(value: preferences),
        ChangeNotifierProvider<MailController>(
          create: (_) => MailController(preferences: preferences)..restore(),
        ),
      ],
      child: const AceMailApp(),
    ),
  );
}
