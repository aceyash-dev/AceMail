import 'package:ace_mail/data/preferences.dart';
import 'package:ace_mail/theme/ace_icons.dart';
import 'package:ace_mail/theme/astryx_theme.dart';
import 'package:ace_mail/widgets/ace_floating_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The nav bar's size, in the box it is actually placed in.
///
/// The bar lives in a `Stack` as a `Positioned(left:, bottom:)`, which hands it
/// *loose* constraints — nothing pins its height. On a phone that produced a
/// bar running from under the app bar to the bottom of the screen, with the
/// labels marooned in the middle of a tall orange pill: a `Container` with a
/// decoration and no height, in a loose box, is as tall as its child decides,
/// and its child was a `Row` whose selected item is a filled pill.
///
/// These tests place it the way the app places it, because the bug only exists
/// in that box. A bar pumped with tight constraints passes either way.
void main() {
  Future<void> pumpBar(WidgetTester tester, {required bool loose}) async {
    final Preferences prefs = Preferences();
    await tester.pumpWidget(
      ChangeNotifierProvider<Preferences>.value(
        value: prefs,
        child: MaterialApp(
          theme: buildAstryxTheme(Brightness.light),
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                const SizedBox.expand(),
                if (loose)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: AceFloatingNav<bool>(
                      value: false,
                      onChanged: (bool _) {},
                      items: const <AceNavItem<bool>>[
                        AceNavItem<bool>(
                          value: false,
                          icon: AceIcons.inbox,
                          label: 'Mail',
                        ),
                        AceNavItem<bool>(
                          value: true,
                          icon: AceIcons.contacts,
                          label: 'Contacts',
                        ),
                      ],
                    ),
                  )
                else
                  AceFloatingNav<bool>(
                    value: false,
                    onChanged: (bool _) {},
                    items: const <AceNavItem<bool>>[
                      AceNavItem<bool>(
                        value: false,
                        icon: AceIcons.inbox,
                        label: 'Mail',
                      ),
                      AceNavItem<bool>(
                        value: true,
                        icon: AceIcons.contacts,
                        label: 'Contacts',
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the bar is one bar high, however it is placed', (
    WidgetTester tester,
  ) async {
    await pumpBar(tester, loose: true);
    final Size loose = tester.getSize(find.byType(AceFloatingNav<bool>));

    await pumpBar(tester, loose: false);
    final Size tight = tester.getSize(find.byType(AceFloatingNav<bool>));

    // 60 for the bar, 4 + 4 for the safe-area padding it sits in, and a little
    // slack for the label animation. What it must not be is the height of the
    // screen.
    expect(loose.height, lessThan(90),
        reason: 'a loose box made the bar ${loose.height} tall');
    expect(loose.height, closeTo(tight.height, 1),
        reason: 'the bar is ${tight.height} when placed tightly and '
            '${loose.height} when placed loosely');
    expect(loose.width, lessThan(360));
    expect(tester.takeException(), isNull);
  });
}
