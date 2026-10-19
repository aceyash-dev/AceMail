import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/mailbox_screen.dart';
import 'screens/sign_in_screen.dart';
import 'state/mail_controller.dart';
import 'theme/astryx_theme.dart';

class AceMailApp extends StatelessWidget {
  const AceMailApp({super.key});

  @override
  Widget build(BuildContext context) {
    final MailController controller = context.watch<MailController>();

    return MaterialApp(
      title: 'Ace Mail',
      debugShowCheckedModeBanner: false,
      theme: buildAstryxTheme(Brightness.light),
      darkTheme: buildAstryxTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home:
          controller.isSignedIn ? const MailboxScreen() : const SignInScreen(),
    );
  }
}
