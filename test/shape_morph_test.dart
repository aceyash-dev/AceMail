import 'dart:math' as math;

import 'package:ace_mail/widgets/shape_morph.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M3Shape profiles', () {
    test('every family is closed and normalised', () {
      for (final M3Shape shape in M3Shape.values) {
        final RadialProfile profile = shape.profile;
        expect(profile.length, shapeSamples, reason: shape.label);
        // Furthest point at 1, so a morph never reads as a zoom.
        expect(profile.reduce(math.max), closeTo(1.0, 1e-9), reason: shape.label);
        expect(profile.every((double r) => r > 0), isTrue, reason: shape.label);
      }
    });

    test('a circle is a circle', () {
      for (final double r in M3Shape.circle.profile) {
        expect(r, closeTo(1.0, 1e-9));
      }
    });

    test('the square families are squarer than the circle', () {
      // Deeper is squarer: a circle has no spread at all.
      double spread(M3Shape shape) {
        final RadialProfile p = shape.profile;
        return p.reduce(math.max) - p.reduce(math.min);
      }

      expect(spread(M3Shape.circle), closeTo(0, 1e-9));
      expect(spread(M3Shape.squircle), greaterThan(0));
      expect(
        spread(M3Shape.roundedSquare),
        greaterThan(spread(M3Shape.squircle)),
        reason: 'a higher superellipse power is a squarer corner',
      );
    });

    test('the corners sit on the diagonals for the square families', () {
      // theta = 0 is an edge midpoint, so the furthest point of a square is a
      // quarter of the way round. Getting this backwards is how a "square"
      // ends up drawn as a diamond.
      for (final M3Shape shape in <M3Shape>[
        M3Shape.squircle,
        M3Shape.roundedSquare,
        M3Shape.cookie,
        M3Shape.clover,
      ]) {
        final RadialProfile p = shape.profile;
        expect(
          p.indexOf(p.reduce(math.max)),
          shapeSamples ~/ 8,
          reason: '${shape.label} should be widest on the diagonal',
        );
      }
    });

    test('a diamond is the other way round: points on the axes', () {
      final RadialProfile p = M3Shape.diamond.profile;
      expect(p.indexOf(p.reduce(math.max)), 0);
      expect(p.indexOf(p.reduce(math.min)), shapeSamples ~/ 8);
    });

    test('the cookie bends inwards — the deepest of the families', () {
      double spread(M3Shape shape) {
        final RadialProfile p = shape.profile;
        return p.reduce(math.max) - p.reduce(math.min);
      }

      // Its edge is drawn in, so its narrowest point is at the edge midpoint
      // and it deforms further than the square it is built on.
      expect(M3Shape.cookie.profile.indexOf(
            M3Shape.cookie.profile.reduce(math.min),
          ),
          0);
      expect(spread(M3Shape.cookie), greaterThan(spread(M3Shape.roundedSquare)));
    });

    test('the clover has four lobes, and they are at the corners', () {
      final RadialProfile p = M3Shape.clover.profile;
      int peaks = 0;
      for (int i = 0; i < p.length; i++) {
        final int prev = (i - 1 + p.length) % p.length;
        final int next = (i + 1) % p.length;
        if (p[i] > p[prev] && p[i] >= p[next]) peaks++;
      }
      expect(peaks, 4);
      expect(p.indexOf(p.reduce(math.max)), shapeSamples ~/ 8);
    });

    test('the cookie and the clover are different shapes, not one bent twice',
        () {
      // Both sit on a rounded square and both have four lobes; what separates
      // them is which way the bend goes.
      final RadialProfile cookie = M3Shape.cookie.profile;
      final RadialProfile clover = M3Shape.clover.profile;
      double edgeToCorner(RadialProfile p) =>
          p.first / p[shapeSamples ~/ 8];
      expect(edgeToCorner(cookie), lessThan(edgeToCorner(clover)));
    });

    test('the pill is wider than it is tall', () {
      final RadialProfile p = M3Shape.pill.profile;
      final double horizontal = p.first; // theta = 0
      final double vertical = p[shapeSamples ~/ 4]; // theta = pi/2
      expect(horizontal, greaterThan(vertical));
    });

    test('sunny has eight lobes', () {
      final RadialProfile p = M3Shape.sunny.profile;
      int peaks = 0;
      for (int i = 0; i < p.length; i++) {
        final int prev = (i - 1 + p.length) % p.length;
        final int next = (i + 1) % p.length;
        if (p[i] > p[prev] && p[i] >= p[next]) peaks++;
      }
      expect(peaks, 8);
    });

    test('a profile is computed once and reused', () {
      expect(identical(M3Shape.circle.profile, M3Shape.circle.profile), isTrue);
    });
  });

  group('lerpProfile', () {
    test('the ends are the shapes themselves', () {
      final RadialProfile a = M3Shape.circle.profile;
      final RadialProfile b = M3Shape.roundedSquare.profile;
      expect(lerpProfile(a, b, 0), orderedEquals(a));
      expect(lerpProfile(a, b, 1), orderedEquals(b));
    });

    test('halfway is between, on every point', () {
      final RadialProfile a = M3Shape.circle.profile;
      final RadialProfile b = M3Shape.roundedSquare.profile;
      final RadialProfile mid = lerpProfile(a, b, 0.5);
      for (int i = 0; i < a.length; i++) {
        expect(mid[i], greaterThanOrEqualTo(math.min(a[i], b[i]) - 1e-9));
        expect(mid[i], lessThanOrEqualTo(math.max(a[i], b[i]) + 1e-9));
      }
    });

    test('t is clamped rather than extrapolated', () {
      final RadialProfile a = M3Shape.circle.profile;
      final RadialProfile b = M3Shape.pill.profile;
      expect(lerpProfile(a, b, -3), orderedEquals(a));
      expect(lerpProfile(a, b, 7), orderedEquals(b));
    });
  });

  group('profileAt', () {
    test('the ends of the cycle are the first and last shapes', () {
      expect(
        profileAt(M3Shape.values, 0),
        orderedEquals(M3Shape.values.first.profile),
      );
      expect(
        profileAt(M3Shape.values, 1),
        orderedEquals(M3Shape.values.last.profile),
      );
    });

    test('it visits every family on the way', () {
      final int steps = M3Shape.values.length;
      for (int i = 0; i < steps; i++) {
        final RadialProfile at =
            profileAt(M3Shape.values, i / (steps - 1));
        expect(
          at,
          orderedEquals(M3Shape.values[i].profile),
          reason: 'family $i should be reached exactly',
        );
      }
    });

    test('the cycle is continuous — no jump between frames', () {
      double maxStep = 0;
      RadialProfile previous = profileAt(M3Shape.values, 0);
      for (int i = 1; i <= 200; i++) {
        final RadialProfile next =
            profileAt(M3Shape.values, i / 200);
        for (int k = 0; k < next.length; k++) {
          maxStep = math.max(maxStep, (next[k] - previous[k]).abs());
        }
        previous = next;
      }
      // A discontinuity would show up as a large single-frame jump.
      expect(maxStep, lessThan(0.05));
    });

    test('a single shape is returned as-is', () {
      expect(
        profileAt(<M3Shape>[M3Shape.circle], 0.5),
        orderedEquals(M3Shape.circle.profile),
      );
    });
  });

  group('easeSegment', () {
    test('holds at each end of the slot', () {
      // The hold is what makes each shape read as a shape.
      expect(morphEase(0), 0);
      expect(morphEase(0.05), 0);
      expect(morphEase(0.95), 1);
      expect(morphEase(1), 1);
    });

    test('rises in between, and never falls', () {
      double previous = -1;
      for (int i = 0; i <= 100; i++) {
        final double value = morphEase(i / 100);
        expect(value, greaterThanOrEqualTo(previous));
        previous = value;
      }
      expect(morphEase(0.5), greaterThan(0.2));
      expect(morphEase(0.5), lessThan(0.8));
    });
  });

  group('profilePath', () {
    test('stays inside the box it was given', () {
      for (final M3Shape shape in M3Shape.values) {
        final Path path = profilePath(shape.profile, const Size(40, 40));
        final Rect bounds = path.getBounds();
        expect(bounds.left, greaterThanOrEqualTo(-0.5), reason: shape.label);
        expect(bounds.top, greaterThanOrEqualTo(-0.5), reason: shape.label);
        expect(bounds.right, lessThanOrEqualTo(40.5), reason: shape.label);
        expect(bounds.bottom, lessThanOrEqualTo(40.5), reason: shape.label);
      }
    });

    test('it is a closed shape with area', () {
      final Path path = profilePath(M3Shape.circle.profile, const Size(40, 40));
      expect(path.contains(const Offset(20, 20)), isTrue);
      expect(path.contains(const Offset(0, 0)), isFalse);
    });
  });

  group('AceShapeMorph widget', () {
    testWidgets('builds and animates without settling', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AceShapeMorph(size: 40))),
      );
      expect(find.byType(AceShapeMorph), findsOneWidget);

      // Still animating a second later: an indicator that stops is a bug.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets('with progress set it does not run a clock', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AceShapeMorph(size: 40, progress: 0.4)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      // Driven by the drag, so it must not be animating on its own.
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
