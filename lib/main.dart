import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'state/mail_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider<MailController>(
      create: (_) => MailController()..restore(),
      child: const AceMailApp(),
    ),
  );
}
