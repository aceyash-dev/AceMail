import 'dart:math' as math;

import 'package:ace_mail/data/accents.dart';
import 'package:ace_mail/theme/astryx_theme.dart';
import 'package:ace_mail/theme/astryx_tokens.dart';
import 'package:ace_mail/widgets/astryx_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: buildAstryxTheme(brightness),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('expressive scheme', () {
    test('the brand orange is still the default accent', () {
      // Not pinned to the raw hex any more: the accent is walked along its own
      // lightness until a label on it clears AA, so the fill can be a step
      // darker than the swatch. It is still orange, and it is still legible.
      final Color primary = buildAstryxScheme(Brightness.light).primary;
      expect(primary.r, greaterThan(primary.b), reason: 'still warm');
      // At most a nudge from the swatch, not a different colour.
      expect(
        (primary.r - AceAccent.orange.seed.r).abs(),
        lessThan(0.25),
      );
      expect(
        contrastRatio(primary, contrastingInk(primary)),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('every accent is usable in both modes', () {
      for (final AceAccent accent in AceAccent.values) {
        for (final Brightness brightness in Brightness.values) {
          final ColorScheme scheme =
              buildAstryxScheme(brightness, accent: accent);
          expect(
            contrastRatio(scheme.primary, scheme.onPrimary),
            greaterThanOrEqualTo(4.5),
            reason: '${accent.label} ${brightness.name}',
          );
        }
      }
    });

    test('the light surface is Milk, pulled towards the accent', () {
      final Color surface = buildAstryxScheme(Brightness.light).surface;
      // Still Milk, but no longer the identical constant for every accent —
      // which is what made the theme feel like it only changed the buttons.
      expect(surface.r, greaterThan(0.9));
      expect(surface.g, greaterThan(0.9));
      expect(surface.b, greaterThan(0.9));
      expect(surface, isNot(const Color(0xFFFFFCF6)));
    });

    test('the page changes with the accent, not just the buttons', () {
      final Color orange =
          buildAstryxScheme(Brightness.light, accent: AceAccent.orange).surface;
      final Color blue =
          buildAstryxScheme(Brightness.light, accent: AceAccent.blue).surface;
      final Color green =
          buildAstryxScheme(Brightness.light, accent: AceAccent.green).surface;

      expect(orange, isNot(blue));
      expect(blue, isNot(green));
      // Blue should be the bluest of the three, green the greenest.
      expect(blue.b, greaterThan(orange.b));
      expect(green.g, greaterThan(orange.g));
    });

    test('carries a full, distinct tonal ramp', () {
      final ColorScheme s = buildAstryxScheme(Brightness.light);
      final List<Color> ramp = <Color>[
        s.surfaceContainerLowest,
        s.surfaceContainerLow,
        s.surfaceContainer,
        s.surfaceContainerHigh,
        s.surfaceContainerHighest,
      ];
      // If any two steps collapse, elevation stops being visible. Tinting
      // must not flatten the ramp.
      expect(ramp.toSet().length, ramp.length);
      // And it should still run light to dark, or "higher" means nothing.
      double luminance(Color c) => c.computeLuminance();
      for (int i = 1; i < ramp.length; i++) {
        expect(
          luminance(ramp[i]),
          lessThanOrEqualTo(luminance(ramp[i - 1]) + 0.001),
          reason: 'step $i should not be brighter than the one below it',
        );
      }
    });

    test('uses the expressive variant, not the default', () {
      final ColorScheme expressive = buildAstryxScheme(Brightness.light);
      final ColorScheme plain = ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF6A1A),
        brightness: Brightness.light,
      );
      // Primary is pinned either way, so compare a role that is not: a
      // difference here is what proves the variant actually took effect.
      expect(expressive.tertiary, isNot(plain.tertiary));
    });

    test('dark mode is dark', () {
      expect(buildAstryxScheme(Brightness.dark).brightness, Brightness.dark);
    });
  });

  group('AstryxColors', () {
    test('is registered on the theme, so context.astryx resolves it', () {
      expect(
        buildAstryxTheme(Brightness.light).extension<AstryxColors>(),
        isNotNull,
      );
      expect(
        buildAstryxTheme(Brightness.dark).extension<AstryxColors>(),
        isNotNull,
      );
    });

    test('maps every Astryx role onto the scheme', () {
      final AstryxColors c =
          AstryxColors.fromScheme(buildAstryxScheme(Brightness.light));

      expect(c.accent, c.scheme.primary);
      expect(c.onAccent, c.scheme.onPrimary);
      expect(c.accentMuted, c.scheme.primaryContainer);
      expect(c.backgroundBody, c.scheme.surface);
      expect(c.textPrimary, c.scheme.onSurface);
      expect(c.textSecondary, c.scheme.onSurfaceVariant);
      expect(c.border, c.scheme.outlineVariant);
      expect(c.errorMuted, c.scheme.errorContainer);
      expect(c.tertiary, c.scheme.tertiary);
    });

    test('lerp is stable at both ends', () {
      final AstryxColors light =
          AstryxColors.fromScheme(buildAstryxScheme(Brightness.light));
      final AstryxColors dark =
          AstryxColors.fromScheme(buildAstryxScheme(Brightness.dark));

      expect(light.lerp(dark, 0).accent, light.accent);
      expect(light.lerp(dark, 1).accent, dark.accent);
    });
  });

  group('AstryxShape', () {
    test('a squircle keeps the full bounds', () {
      final Path squircle =
          AstryxShape.squircle(const Rect.fromLTWH(0, 0, 100, 100));
      expect(squircle.getBounds().width, closeTo(100, 0.5));
      expect(squircle.getBounds().height, closeTo(100, 0.5));
    });

    test('a squircle corner reaches further than a circular one', () {
      const Rect rect = Rect.fromLTWH(0, 0, 100, 100);
      // Corner radius 25 either way. On the diagonal the circular arc's
      // boundary sits at 25 from the corner centre and the superellipse's at
      // 29.7, so a probe at 28.3 is outside one and inside the other.
      const Offset probe = Offset(5, 5);
      expect(AstryxShape.squircle(rect, exponent: 2).contains(probe), isFalse);
      expect(AstryxShape.squircle(rect, exponent: 4).contains(probe), isTrue);
    });

    test('a wide card keeps straight edges instead of going oval', () {
      // This is the bug the shape was rebuilt for: one superellipse stretched
      // over a wide, short rect has no straight edges at all, so a settings
      // card rendered as an oval. The corners are superelliptical now; the
      // edges between them are straight.
      const Rect card = Rect.fromLTWH(0, 0, 300, 100);
      final Path path = AstryxShape.squircle(card);

      expect(path.contains(const Offset(30, 2)), isTrue,
          reason: 'the top edge is straight');
      expect(path.contains(const Offset(150, 1)), isTrue);
      expect(path.contains(const Offset(2, 50)), isTrue,
          reason: 'the left edge is straight');
      // ...and the corner is still cut.
      expect(path.contains(const Offset(1, 1)), isFalse);
    });

    test('an explicit radius is honoured', () {
      final Path tight =
          AstryxShape.squircle(const Rect.fromLTWH(0, 0, 100, 100), radius: 0);
      expect(tight.contains(const Offset(1, 1)), isTrue,
          reason: 'a zero radius is a plain rectangle');
    });

    test('the squircle border is a valid ShapeBorder', () {
      const AceSquircleBorder border = AceSquircleBorder();
      final Path path =
          border.getOuterPath(const Rect.fromLTWH(0, 0, 40, 40));
      expect(path.getBounds().width, closeTo(40, 0.5));
      expect(border.copyWith().exponent, 4);
    });
  });

  group('AstryxMotion', () {
    double ratio(SpringDescription s) =>
        s.damping / (2 * math.sqrt(s.mass * s.stiffness));

    test('spatial springs settle with a little overshoot', () {
      expect(ratio(AstryxMotion.spatialFast), lessThan(1.0));
      expect(ratio(AstryxMotion.spatialDefault), lessThan(1.0));
      expect(ratio(AstryxMotion.spatialSlow), lessThan(1.0));
    });

    test('effects springs are critically damped, so colour never wobbles', () {
      expect(ratio(AstryxMotion.effectsFast), closeTo(1.0, 0.05));
      expect(ratio(AstryxMotion.effectsDefault), closeTo(1.0, 0.05));
    });

    test('the press spring is the liveliest of them', () {
      expect(ratio(AstryxMotion.press), lessThan(0.7));
    });

    test('a faster spring is stiffer', () {
      expect(
        AstryxMotion.spatialFast.stiffness,
        greaterThan(AstryxMotion.spatialDefault.stiffness),
      );
      expect(
        AstryxMotion.spatialDefault.stiffness,
        greaterThan(AstryxMotion.spatialSlow.stiffness),
      );
    });
  });

  group('expressive widgets', () {
    testWidgets('AceButton shows its label and fires once', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(
          AceButton(
            label: 'Send',
            variant: AceButtonVariant.primary,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(find.text('Send'), findsOneWidget);
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('a disabled AceButton does not fire', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const AceButton(label: 'Send', onPressed: null)),
      );
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      // Reaching here without an exception is the assertion: there is no
      // callback to call.
      expect(find.text('Send'), findsOneWidget);
    });

    testWidgets('AceIconButton carries its tooltip', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(AceIconButton(icon: Icons.star, onPressed: () {}, tooltip: 'Flag')),
      );
      expect(find.byTooltip('Flag'), findsOneWidget);
    });

    testWidgets('AceFab extends to show its label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(AceFab(label: 'Compose', icon: Icons.edit, onPressed: () {})),
      );
      expect(find.text('Compose'), findsOneWidget);
    });

    testWidgets('AceToolbar lays out every action', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AceToolbar(
            actions: <AceToolbarAction>[
              AceToolbarAction(
                icon: Icons.reply,
                tooltip: 'Reply',
                onPressed: () {},
              ),
              AceToolbarAction(
                icon: Icons.delete_outline,
                tooltip: 'Delete',
                destructive: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.byTooltip('Reply'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsOneWidget);
    });

    testWidgets('AceLoader morphs continuously without settling', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const AceLoader()));
      await tester.pump(const Duration(milliseconds: 400));
      final CustomPaint first = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(AceLoader),
          matching: find.byType(CustomPaint),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      final CustomPaint later = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(AceLoader),
          matching: find.byType(CustomPaint),
        ),
      );
      // It repeats forever, so settle would never return — and the painter
      // must actually be handed a new value as time passes.
      expect(first.painter, isNot(same(later.painter)));
    });

    testWidgets('InitialsAvatar paints inside a continuous corner', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const InitialsAvatar(initials: 'PS', seed: 'p@x.com')),
      );
      expect(find.text('PS'), findsOneWidget);
    });

    testWidgets('every expressive component builds in dark mode too', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: <Widget>[
              const AceLoader(),
              const InitialsAvatar(initials: 'AB'),
              AceChip(label: 'Chip', selected: true, onTap: () {}),
              AceListTile(title: 'Row', subtitle: 'Sub', onTap: () {}),
            ],
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Chip'), findsOneWidget);
      expect(find.text('Row'), findsOneWidget);
    });
  });
}
