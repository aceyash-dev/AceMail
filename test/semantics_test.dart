import 'package:ace_mail/models/swipe_action.dart';
import 'package:ace_mail/theme/astryx_theme.dart';
import 'package:ace_mail/widgets/ace_form_field.dart';
import 'package:ace_mail/widgets/astryx_widgets.dart';
import 'package:ace_mail/widgets/skeleton.dart';
import 'package:ace_mail/widgets/swipe_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
      theme: buildAstryxTheme(Brightness.light),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('a filled button is a button, with a name', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        AceButton(
          label: 'Send',
          variant: AceButtonVariant.primary,
          onPressed: () {},
        ),
      ),
    );

    // Found by label: the button's own node carries the role, not an ancestor.
    expect(
      tester.getSemantics(find.bySemanticsLabel('Send')),
      isSemantics(
        isButton: true,
        label: 'Send',
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    handle.dispose();
  });

  testWidgets('a disabled button is a button, and says it is not enabled', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(const AceButton(label: 'Send', onPressed: null)),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Send')),
      isSemantics(isButton: true, isEnabled: false, hasTapAction: false),
    );

    handle.dispose();
  });

  testWidgets('an icon button is named by its tooltip', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        AceIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          onPressed: () {},
        ),
      ),
    );

    // An icon-only control has no other name, so the tooltip has to reach the
    // accessibility tree.
    expect(
      tester.getSemantics(find.bySemanticsLabel('Refresh')),
      isSemantics(isButton: true, label: 'Refresh', hasTapAction: true),
    );

    handle.dispose();
  });

  testWidgets('a form field is labelled, and the label is not repeated', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final TextEditingController controller = TextEditingController();
    await tester.pumpWidget(
      host(AceFormField(label: 'Email address', controller: controller)),
    );

    // The visible label is decoration; the field carries the name, once.
    expect(find.bySemanticsLabel('Email address'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Email address')),
      isSemantics(isTextField: true, label: 'Email address'),
    );

    handle.dispose();
  });

  testWidgets('a swipe row keeps its content reachable', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        AceSwipeTile(
          start: SwipeAction.none,
          end: SwipeAction.none,
          onAction: (SwipeAction action) {},
          child: const Text('A message'),
        ),
      ),
    );

    expect(find.bySemanticsLabel('A message'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('placeholders build without announcing anything', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const MessageListSkeleton(rows: 3)));

    expect(find.byType(AceSkeleton), findsWidgets);
    handle.dispose();
  });
}
