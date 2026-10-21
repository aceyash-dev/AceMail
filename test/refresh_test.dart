import 'package:ace_mail/data/preferences.dart';
import 'package:ace_mail/state/mail_controller.dart';
import 'package:ace_mail/theme/astryx_theme.dart';
import 'package:ace_mail/widgets/message_list_panel.dart';
import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fake_transport.dart';

void main() {
  Future<MailController> pumpPanel(WidgetTester tester, FakeTransport transport) async {
    final MailController controller = MailController(
      store: FakeStore(),
      transportFactory: (_, __) => transport,
    );
    await controller.signIn(accountA, 'p');

    // Deliberately not loaded: reading the keychain needs a platform channel,
    // which under testWidgets never answers. The defaults are what a fresh
    // install has, and they are enough here.
    final Preferences prefs = Preferences();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MailController>.value(value: controller),
          ChangeNotifierProvider<Preferences>.value(value: prefs),
        ],
        child: MaterialApp(
          theme: buildAstryxTheme(Brightness.light),
          home: const Scaffold(body: MessageListPanel()),
        ),
      ),
    );
    // Explicit frames: the loading indicator morphs continuously by design, so
    // nothing in this tree ever settles.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    return controller;
  }

  testWidgets('the list can overscroll, which is what a pull needs', (
    WidgetTester tester,
  ) async {
    final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(12));
    await pumpPanel(tester, transport);

    final ScrollableState scrollable =
        tester.state(find.byType(Scrollable).first);

    // On Android the default physics clamps, and a clamped list never
    // overscrolls — so CupertinoSliverRefreshControl never fires and a pull does
    // nothing. The physics has to permit it, on every platform.
    expect(scrollable.position.physics, isA<BouncingScrollPhysics>());
    expect(
      scrollable.position.physics.shouldAcceptUserOffset(scrollable.position),
      isTrue,
    );
  });

  testWidgets('the refresh control is the first sliver, so it sees the pull', (
    WidgetTester tester,
  ) async {
    final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(12));
    await pumpPanel(tester, transport);

    final CustomScrollView view = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    expect(view.slivers.first, isA<CupertinoSliverRefreshControl>());
  });

  testWidgets('pulling past the trigger distance refreshes the folder', (
    WidgetTester tester,
  ) async {
    final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(12));
    await pumpPanel(tester, transport);

    final int before = transport.pageFetches;

    // A drag that goes well past the trigger distance.
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(CustomScrollView)),
    );
    for (int i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await gesture.up();
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    expect(
      transport.pageFetches,
      greaterThan(before),
      reason: 'the pull should have reloaded the folder',
    );
  });
}
