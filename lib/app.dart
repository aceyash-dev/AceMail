import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/mailbox_screen.dart';
import 'screens/sign_in_screen.dart';
import 'state/mail_controller.dart';
import 'theme/astryx_theme.dart';
import 'theme/astryx_tokens.dart';
import 'widgets/astryx_widgets.dart';

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
      home: controller.restoring
          ? const _RestoringScreen()
          : (controller.isSignedIn
              ? const MailboxScreen()
              : const SignInScreen()),
    );
  }
}

/// Shown for the moment it takes to read saved accounts back from the
/// keychain. The Ace mark keeps it in step with the native launch window.
class _RestoringScreen extends StatelessWidget {
  const _RestoringScreen();

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    return Scaffold(
      backgroundColor: c.backgroundBody,
      body: const Center(child: AceLoader()),
    );
  }
}
