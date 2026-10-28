import 'dart:async';

import 'package:ace_mail/data/preferences.dart';
import 'package:ace_mail/models/ace_account.dart';
import 'package:ace_mail/screens/sign_in_screen.dart';
import 'package:ace_mail/services/google_auth.dart';
import 'package:ace_mail/state/mail_controller.dart';
import 'package:ace_mail/theme/astryx_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _TestMailController extends MailController {
  int signInCalls = 0;
  AceAccount? signedInAccount;
  String? receivedCredential;

  @override
  Future<bool> signIn(
    AceAccount candidate,
    String password, {
    bool remember = true,
  }) async {
    signInCalls += 1;
    signedInAccount = candidate;
    receivedCredential = password;
    return true;
  }
}

Future<void> _pumpSignInScreen(
  WidgetTester tester,
  _TestMailController controller, {
  required Future<GoogleCredential> Function() googleSignIn,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MailController>.value(value: controller),
        // The sheet draws the app's material, and the material asks the
        // preferences which kind. A real app always has one; a test has to say
        // so.
        ChangeNotifierProvider<Preferences>.value(value: Preferences()),
      ],
      child: MaterialApp(
        theme: buildAstryxTheme(Brightness.light),
        home: SignInScreen(googleSignIn: googleSignIn),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Walks the two steps to the credentials screen, with a Google address.
///
/// The Google button is not on the welcome screen and not on the address step.
/// It is on the credentials step, and only when the domain chosen is a Google
/// one — a Google button in front of somebody who has just typed their work
/// address at a company running its own mail is a button that cannot work. That
/// is the placement, so this is what the tests have to do to reach it.
Future<void> _walkToCredentials(
  WidgetTester tester, {
  String username = 'someone',
}) async {
  // The first screen is the provider question now: tapping the mark is what
  // "Get started" used to be, and it answers the same question the next screen
  // would have asked.
  await tester.tap(find.text('Gmail'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, username);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Google login shows progress and ignores taps while OAuth is pending',
    (WidgetTester tester) async {
      final _TestMailController controller = _TestMailController();
      final Completer<GoogleCredential> auth = Completer<GoogleCredential>();
      int authAttempts = 0;

      await _pumpSignInScreen(
        tester,
        controller,
        googleSignIn: () {
          authAttempts += 1;
          return auth.future;
        },
      );

      // Not on the welcome screen: nothing has been chosen yet, so there is no
      // answer to "is this a Google account".
      expect(find.text('Continue with Google'), findsNothing);

      await _walkToCredentials(tester);

      final Finder googleButton = find.text('Continue with Google');
      expect(googleButton, findsOneWidget);
      await tester.ensureVisible(googleButton);
      await tester.tap(googleButton);
      await tester.pump();

      expect(authAttempts, 1);
      expect(find.text('Signing in…'), findsOneWidget);

      // The button stays visible, but no longer invokes the OAuth callback.
      await tester.tap(find.text('Signing in…'));
      await tester.pump();
      expect(authAttempts, 1);

      auth.complete((
        email: 'someone@gmail.com',
        token: 'test-access-token',
        name: 'Someone',
      ));
      await tester.pumpAndSettle();

      expect(controller.signInCalls, 1);
      expect(controller.signedInAccount?.email, 'someone@gmail.com');
      expect(controller.signedInAccount?.auth, MailAuth.google);
      expect(controller.receivedCredential, 'test-access-token');
      expect(find.text('Continue with Google'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('unexpected Google auth errors are shown and can be retried', (
    WidgetTester tester,
  ) async {
    final _TestMailController controller = _TestMailController();
    int authAttempts = 0;

    await _pumpSignInScreen(
      tester,
      controller,
      googleSignIn: () async {
        authAttempts += 1;
        throw StateError('platform channel failed');
      },
    );

    expect(find.text('Continue with Google'), findsNothing);
    await _walkToCredentials(tester);

    final Finder googleButton = find.text('Continue with Google');
    expect(googleButton, findsOneWidget);
    await tester.ensureVisible(googleButton);
    await tester.tap(googleButton);
    await tester.pumpAndSettle();

    expect(authAttempts, 1);
    expect(
      find.text(
        'Google sign-in could not be completed. Check your connection and '
        'Google sign-in configuration, then try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Continue with Google'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

