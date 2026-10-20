import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/preferences.dart';
import 'state/mail_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<Preferences>(
          create: (_) => Preferences()..load(),
        ),
        ChangeNotifierProvider<MailController>(
          create: (_) => MailController()..restore(),
        ),
      ],
      child: const AceMailApp(),
    ),
  );
}
