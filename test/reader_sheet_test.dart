import 'package:ace_mail/data/preferences.dart';
import 'package:ace_mail/screens/mailbox_screen.dart';
import 'package:ace_mail/state/mail_controller.dart';
import 'package:ace_mail/theme/astryx_theme.dart';
import 'package:ace_mail/widgets/message_list_panel.dart';
import 'package:ace_mail/widgets/message_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fake_transport.dart';

/// A message on a phone is a sheet over the list, not a page that replaces it.
///
/// Two things follow from that and both are easy to get wrong: the chevron that
/// belonged to the page is gone, and the sheet and the open message have to stay
/// in step in both directions — opening raises the sheet, and dragging the sheet
/// away closes the message rather than leaving the app thinking it is still
/// reading one.
void main() {
  /// Explicit frames: the loading shimmer animates continuously by design, so
  /// nothing in this tree ever settles.
  Future<void> frames(WidgetTester tester, {int count = 14}) async {
    for (int i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  /// Disposes the tree, which is what cancels the screen's refresh timer.
  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }

  Future<MailController> pumpMailbox(
    WidgetTester tester,
    FakeTransport transport,
  ) async {
    // A phone, because that is the layout the sheet belongs to.
    tester.view.physicalSize = const Size(420, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final MailController controller = MailController(
      store: FakeStore(),
      transportFactory: (_, __) => transport,
    );
    await controller.signIn(accountA, 'p');

    // Deliberately not loaded: reading the keychain needs a platform channel,
    // which under testWidgets never answers.
    final Preferences prefs = Preferences();

    await tester.pumpWidget(
      MultiProvider(
        providers: <ChangeNotifierProvider<ChangeNotifier>>[
          ChangeNotifierProvider<MailController>.value(value: controller),
          ChangeNotifierProvider<Preferences>.value(value: prefs),
        ],
        child: MaterialApp(
          theme: buildAstryxTheme(Brightness.light),
          home: const MailboxScreen(),
        ),
      ),
    );
    await frames(tester);
    return controller;
  }

  testWidgets('opens over the list, as a sheet, with no back chevron', (
    WidgetTester tester,
  ) async {
    final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(3));
    final MailController controller = await pumpMailbox(tester, transport);

    await controller.open(controller.messages.first);
    await frames(tester);

    expect(find.byType(MessageReader), findsOneWidget);
    expect(
      find.byType(BottomSheet),
      findsOneWidget,
      reason: 'the reader is a sheet, not a page',
    );
    expect(
      find.byTooltip('Back'),
      findsNothing,
      reason: 'a sheet has a handle; a chevron would be a second way out',
    );
    // The list is still there behind it, not swapped out.
    expect(find.byType(MessageListPanel), findsOneWidget);

    await teardown(tester);
  });

  testWidgets('closing the message takes the sheet with it', (
    WidgetTester tester,
  ) async {
    final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(3));
    final MailController controller = await pumpMailbox(tester, transport);

    await controller.open(controller.messages.first);
    await frames(tester);
    expect(find.byType(MessageReader), findsOneWidget);

    controller.closeMessage();
    await frames(tester);

    expect(find.byType(MessageReader), findsNothing);
    expect(controller.openSummary, isNull);

    await teardown(tester);
  });

  testWidgets('dragging the sheet away closes the message', (
    WidgetTester tester,
  ) async {
    final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(3));
    final MailController controller = await pumpMailbox(tester, transport);

    await controller.open(controller.messages.first);
    await frames(tester);
    expect(controller.openSummary, isNotNull);

    // Down and away, the way the handle is dragged.
    await tester.fling(
      find.byType(MessageReader),
      const Offset(0, 600),
      1500,
    );
    await frames(tester);

    expect(controller.openSummary, isNull, reason: 'the sheet was dismissed');
    expect(find.byType(MessageReader), findsNothing);

    await teardown(tester);
  });
}
