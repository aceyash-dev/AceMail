import 'package:ace_mail/theme/ace_icons.dart';
import 'package:ace_mail/theme/astryx_theme.dart';
import 'package:ace_mail/widgets/ace_icon_view.dart';
import 'package:ace_mail/widgets/astryx_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';

/// The icons were rendered at the size of whatever box they sat in rather than
/// the size they were given, because a Container with a width and height hands
/// its child *tight* constraints. Every optical correction was being
/// overwritten, which is why four attempts at making them smaller changed
/// nothing. This is the test that would have caught it the first time.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstryxTheme(Brightness.light),
        home: Scaffold(body: Center(child: child)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  double rendered(WidgetTester tester, Finder finder) =>
      (finder.evaluate().single.renderObject! as RenderBox).size.width;

  testWidgets('an icon is drawn at the size it is asked for', (
    WidgetTester tester,
  ) async {
    await pump(tester, const AceIconView(icon: AceIcons.star, size: 18));
    final double drawn = rendered(tester, find.byType(HugeIcon));
    expect(drawn, closeTo(18 * AceIconView.opticalScale, 0.1));
  });

  testWidgets('an icon inside a button is not stretched to the button', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      AceIconButton(icon: AceIcons.star, tooltip: 'star', onPressed: () {}),
    );

    final double button = rendered(tester, find.byType(AceIconButton));
    final double icon = rendered(tester, find.byType(HugeIcon));

    expect(button, greaterThan(30), reason: 'still a touch target');
    expect(
      icon,
      lessThan(button * 0.7),
      reason: 'the icon must not fill the button it sits in',
    );
  });

  testWidgets('a bigger button gets a proportionally bigger icon', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AceIconButton(
            icon: AceIcons.star,
            tooltip: 'small',
            onPressed: () {},
          ),
          AceIconButton(
            icon: AceIcons.star,
            tooltip: 'big',
            size: 72,
            onPressed: () {},
          ),
        ],
      ),
    );

    final List<double> sizes = find
        .byType(HugeIcon)
        .evaluate()
        .map((Element e) => (e.renderObject! as RenderBox).size.width)
        .toList();

    expect(sizes.length, 2);
    expect(sizes[1], greaterThan(sizes[0]));
    // Not just bigger — the ratio is what was asked for.
    expect(sizes[1] / sizes[0], closeTo(72 / 44, 0.05));
  });

  testWidgets('an icon in an app bar slot is not stretched to the slot', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstryxTheme(Brightness.light),
        home: Scaffold(
          appBar: AppBar(
            leading: AceIconButton(
              icon: AceIcons.menu,
              tooltip: 'Folders',
              onPressed: () {},
            ),
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(rendered(tester, find.byType(HugeIcon)), lessThan(30));
  });
}
