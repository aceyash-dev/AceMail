import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/preferences.dart';
import 'screens/mailbox_screen.dart';
import 'screens/sign_in_screen.dart';
import 'state/mail_controller.dart';
import 'theme/astryx_theme.dart';

class AceMailApp extends StatelessWidget {
  const AceMailApp({super.key});

  @override
  Widget build(BuildContext context) {
    final MailController controller = context.watch<MailController>();
    final Preferences prefs = context.watch<Preferences>();

    return MaterialApp(
      title: 'Ace Mail',
      debugShowCheckedModeBanner: false,
      theme: buildAstryxTheme(Brightness.light),
      darkTheme: buildAstryxTheme(Brightness.dark),
      themeMode: switch (prefs.themeMode) {
        AceThemeMode.system => ThemeMode.system,
        AceThemeMode.light => ThemeMode.light,
        AceThemeMode.dark => ThemeMode.dark,
      },
      builder: (BuildContext context, Widget? child) {
        // The app's text-size setting multiplies the device setting rather
        // than replacing it, so a system accessibility size still applies.
        final MediaQueryData data = MediaQuery.of(context);
        final double systemScale = data.textScaler.scale(1);
        return MediaQuery(
          data: data.copyWith(
            textScaler: TextScaler.linear(systemScale * prefs.textScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      // No loading screen: the keychain is read before the first frame, so
      // this is already the answer.
      home: controller.isSignedIn
          ? const MailboxScreen()
          : const SignInScreen(),
    );
  }
}
