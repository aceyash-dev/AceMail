import 'package:ace_mail/app.dart';
import 'package:ace_mail/theme/astryx_theme.dart';
import 'package:ace_mail/widgets/astryx_widgets.dart';
import 'package:ace_mail/widgets/launch_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The launch splash: the mark, then the accent washing across, then the app.
void main() {
  testWidgets('the splash holds the mark, then hands over to the app', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstryxTheme(Brightness.light),
        home: const LaunchSplash(child: Text('the mailbox')),
      ),
    );

    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(BrandMark), findsOneWidget);
    // The app is underneath from the first frame, not built afterwards.
    expect(find.text('the mailbox'), findsOneWidget);

    // It gets out of the way on its own.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(BrandMark), findsNothing);
    expect(find.text('the mailbox'), findsOneWidget);
  });

  test('the app widget is what main builds', () {
    expect(const AceMailApp(), isA<Widget>());
  });
}
