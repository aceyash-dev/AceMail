import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/app_info.dart';
import 'data/preferences.dart';
import 'screens/mailbox_screen.dart';
import 'screens/sign_in_screen.dart';
import 'state/mail_controller.dart';
import 'theme/astryx_theme.dart';
import 'theme/astryx_tokens.dart';
import 'widgets/app_lock_gate.dart';
import 'widgets/update_sheet.dart';
import 'widgets/whats_new.dart';
import 'util/haptics.dart';

class AceMailApp extends StatelessWidget {
  const AceMailApp({super.key});

  /// Shows the release notes when the version has changed, then records that it
  /// has been seen.
  void _maybeAnnounceUpdate(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;
      await WhatsNewSheet.showIfUpdated(context);
      if (!context.mounted) return;
      await context
          .read<Preferences>()
          .setLastSeenVersion(AppInfo.fullVersion);
      // After the release notes, and never in front of them: what changed in
      // *this* build comes before what has changed since.
      if (!context.mounted) return;
      await announceUpdateIfAny(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final MailController controller = context.watch<MailController>();
    final Preferences prefs = context.watch<Preferences>();

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // The platform's accent, when the setting is on. Used as the seed for
        // the app's own pipeline rather than taken wholesale, so contrast and
        // the tinted surfaces are still handled.
        final Color? seed = prefs.useDynamicColour
            ? (lightDynamic?.primary ?? darkDynamic?.primary)
            : null;

        // Typed as a Widget: the builder wants a Widget, and Dart would
        // otherwise infer the narrower MaterialApp and refuse.
        final Widget app = MaterialApp(
      title: 'Ace Mail',
      debugShowCheckedModeBanner: false,
      // Rebuilt from the preference, so changing the accent re-themes the app
      // in place rather than on the next launch.
      theme: buildAstryxTheme(
        Brightness.light,
        accent: prefs.accent,
        dynamicSeed: seed,
      ),
      darkTheme: buildAstryxTheme(
        Brightness.dark,
        accent: prefs.accent,
        dynamicSeed: seed,
        oled: prefs.oled,
      ),
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

        // The system bars follow the theme. Without this the navigation bar is
        // whatever Android last felt like — which is black, and looks like a
        // hole cut out of a cream page.
        // One switch for the whole app, read where the preferences already are.
        AceHaptics.enabled = prefs.haptics;
        AstryxMotion.reduced = prefs.reduceMotion;

        final AstryxColors c = context.astryx;
        final bool dark = Theme.of(context).brightness == Brightness.dark;
        final Brightness icons =
            dark ? Brightness.light : Brightness.dark;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: icons,
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: c.backgroundBody,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: icons,
          ),
          child: MediaQuery(
            data: data.copyWith(
              textScaler: TextScaler.linear(systemScale * prefs.textScale),
            ),
            // The lock sits above everything, including the sheets and the
            // reader, so there is no screen that shows mail while it is up.
            child: AppLockGate(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
      home: _AnnounceOnFirstFrame(
        onReady: _maybeAnnounceUpdate,
        child: _home(controller),
      ),
        );
        return app;
      },
    );
  }
}

extension on AceMailApp {
  /// Straight to the work.
  ///
  /// There was a separate splash for the first connection. It was a second
  /// loading screen for something the mailbox already shows — the list has a
  /// skeleton while it loads, and the app bar says which folder is coming. Two
  /// of them meant waiting twice.
  Widget _home(MailController controller) {
    if (!controller.isSignedIn && !controller.exploring) {
      return const SignInScreen();
    }
    return const MailboxScreen();
  }
}

/// Runs [onReady] once, after the first frame has been laid out.
///
/// The release notes are a sheet, and a sheet needs a Navigator — which does
/// not exist until there is a tree to hang it from.
class _AnnounceOnFirstFrame extends StatefulWidget {
  const _AnnounceOnFirstFrame({required this.onReady, required this.child});

  final void Function(BuildContext context) onReady;
  final Widget child;

  @override
  State<_AnnounceOnFirstFrame> createState() => _AnnounceOnFirstFrameState();
}

class _AnnounceOnFirstFrameState extends State<_AnnounceOnFirstFrame> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
