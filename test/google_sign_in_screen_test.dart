import 'dart:async';

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
    ChangeNotifierProvider<MailController>.value(
      value: controller,
      child: MaterialApp(
        theme: buildAstryxTheme(Brightness.light),
        home: SignInScreen(googleSignIn: googleSignIn),
      ),
    ),
  );
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

      expect(find.text('Continue with Google'), findsOneWidget);
      await tester.tap(find.text('Continue with Google'));
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

    await tester.tap(find.text('Continue with Google'));
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
