import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/astryx_tokens.dart';

/// A shape, as the distance from its centre at each of [sampleCount] angles.
///
/// Interpolating two of these is a true shape morph: every point travels, so
/// the shape passes through the intermediate forms rather than one formula
/// being tuned towards another. That is how Material's own shape morphing
/// works, and it is why a circle morphing to a square here bulges through a
/// rounded diamond instead of snapping.
typedef RadialProfile = List<double>;

/// How many angles a profile is sampled at. High enough that the curves read as
/// curves, low enough that interpolating 128 doubles a frame is free.
const int shapeSamples = 128;

/// Material's shape families.
///
/// Each is a closed curve on the unit circle, normalised so its furthest point
/// sits at 1 — without that, morphing between a circle and a pill would look
/// like a zoom as much as a morph.
enum M3Shape {
  circle('Circle'),
  squircle('Squircle'),
  roundedSquare('Rounded square'),
  cookie('Cookie'),
  clover('Clover'),
  pill('Pill'),
  diamond('Diamond'),
  sunny('Sunny');

  const M3Shape(this.label);

  final String label;

  /// Radius at [theta], before normalisation.
  double _raw(double theta) {
    final double c = math.cos(theta).abs();
    final double s = math.sin(theta).abs();

    /// A superellipse: n = 2 is a circle, higher is squarer.
    double superellipse(double n) =>
        1 / math.pow(math.pow(c, n) + math.pow(s, n), 1 / n).toDouble();

    switch (this) {
      case M3Shape.circle:
        return 1;
      case M3Shape.squircle:
        return superellipse(4);
      case M3Shape.roundedSquare:
        return superellipse(6);
      case M3Shape.diamond:
        return superellipse(1.4);
      case M3Shape.pill:
        // An ellipse, wide and short.
        const double a = 1.0;
        const double b = 0.66;
        return 1 / math.sqrt((c * c) / (a * a) + (s * s) / (b * b));
      case M3Shape.cookie:
        // A rounded square with its edges drawn in — the bend is deepest at the
        // middle of each edge, which is where cos(2θ)² peaks.
        final double bend = math.cos(2 * theta);
        return superellipse(5) * (1 - 0.22 * bend * bend);
      case M3Shape.clover:
        // Lobes at the corners, so the push is at sin(2θ)².
        final double lobe = math.sin(2 * theta);
        return superellipse(3) * (1 + 0.16 * lobe * lobe);
      case M3Shape.sunny:
        return 1 + 0.10 * math.cos(8 * theta);
    }
  }

  /// The normalised profile for this family. Computed once.
  RadialProfile get profile => _profiles.putIfAbsent(this, () {
        final List<double> raw = <double>[
          for (int i = 0; i < shapeSamples; i++)
            _raw(2 * math.pi * i / shapeSamples),
        ];
        final double max = raw.reduce(math.max);
        return <double>[for (final double r in raw) r / max];
      });

  static final Map<M3Shape, RadialProfile> _profiles =
      <M3Shape, RadialProfile>{};
}

/// Element-wise interpolation between two profiles.
RadialProfile lerpProfile(RadialProfile a, RadialProfile b, double t) {
  final double k = t.clamp(0.0, 1.0);
  return <double>[
    for (int i = 0; i < a.length; i++) lerpDouble(a[i], b[i], k)!,
  ];
}

/// The path a profile describes, fitted into [size].
///
/// A cubic through the sampled points rather than straight lines between them:
/// 128 segments would look smooth, but the curve makes a small morph look right
/// at 32 samples too, which is what a 24px indicator gets.
Path profilePath(RadialProfile profile, Size size, {double rotation = 0}) {
  final double cx = size.width / 2;
  final double cy = size.height / 2;
  final double scale = math.min(size.width, size.height) / 2;

  final Path path = Path();
  for (int i = 0; i <= profile.length; i++) {
    final int index = i % profile.length;
    final double theta = 2 * math.pi * index / profile.length + rotation;
    final double r = profile[index] * scale;
    final double x = cx + r * math.cos(theta);
    final double y = cy + r * math.sin(theta);

    if (i == 0) {
      path.moveTo(x, y);
      continue;
    }

    // Control points along the tangent, so the joins stay round.
    final int prev = (index - 1 + profile.length) % profile.length;
    final double prevTheta = 2 * math.pi * prev / profile.length + rotation;
    final double prevR = profile[prev] * scale;
    final double px = cx + prevR * math.cos(prevTheta);
    final double py = cy + prevR * math.sin(prevTheta);

    final double dx = (x - px) / 6;
    final double dy = (y - py) / 6;
    path.cubicTo(px + dx, py + dy, x - dx, y - dy, x, y);
  }
  path.close();
  return path;
}

/// Holds each shape for the first and last fifth of its slot, and travels in
/// between with a cubic — so the shape *settles* rather than arriving.
///
/// The hold is what makes each one read as a shape. A morph that never rests is
/// a blob.
double morphEase(double t) {
  const double hold = 0.2;
  final double x = ((t - hold / 2) / (1 - hold)).clamp(0.0, 1.0);
  return Curves.easeInOutCubic.transform(x);
}

/// The profile at a point in the cycle, where [progress] runs 0 to 1 across
/// every shape in turn, reaching each one exactly.
RadialProfile profileAt(List<M3Shape> shapes, double progress) {
  if (shapes.isEmpty) return M3Shape.circle.profile;
  if (shapes.length < 2) return shapes.first.profile;

  final double scaled = progress.clamp(0.0, 1.0) * (shapes.length - 1);
  final int index = scaled.floor().clamp(0, shapes.length - 2);
  final double local = morphEase(scaled - index);

  return lerpProfile(
    shapes[index].profile,
    shapes[index + 1].profile,
    local,
  );
}

/// The Material 3 Expressive loading indicator: a shape that morphs through the
/// shape families, holding each one briefly before springing into the next.
///
/// The hold matters. A shape that never rests is a blob; Material's indicator
/// reads as a sequence of *shapes* because each one lands, sits for a moment,
/// and then moves on.
class AceShapeMorph extends StatefulWidget {
  const AceShapeMorph({
    super.key,
    this.size = 44,
    this.color,
    this.progress,
    this.shapes = M3Shape.values,
  });

  final double size;
  final Color? color;

  /// When set, the morph is scrubbed by this instead of looping — 0 is the
  /// first shape, 1 the last. Used by pull-to-refresh, where the drag is the
  /// clock.
  final double? progress;

  final List<M3Shape> shapes;

  @override
  State<AceShapeMorph> createState() => _AceShapeMorphState();
}

class _AceShapeMorphState extends State<AceShapeMorph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // Long enough that each shape lands rather than flashing past.
    duration: const Duration(milliseconds: 3400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.progress == null) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant AceShapeMorph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress == null && !_controller.isAnimating) {
      _controller.repeat();
    } else if (widget.progress != null && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.color ?? context.astryx.accent;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, _) {
          final double progress = widget.progress ?? _controller.value;
          return CustomPaint(
            painter: _MorphPainter(
              profile: profileAt(widget.shapes, progress),
              color: color,
              // A slow turn, so a shape with lobes reads as turning rather than
              // as pulsing.
              rotation: progress * math.pi * 0.5,
            ),
          );
        },
      ),
    );
  }
}

class _MorphPainter extends CustomPainter {
  const _MorphPainter({
    required this.profile,
    required this.color,
    required this.rotation,
  });

  final RadialProfile profile;
  final Color color;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      profilePath(profile, size, rotation: rotation),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _MorphPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.rotation != rotation ||
      !identical(oldDelegate.profile, profile);
}
