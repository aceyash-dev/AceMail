import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/astryx_tokens.dart';
import 'astryx_widgets.dart';

/// The app's own splash: the mark, then the accent washing across, then the UI.
///
/// The native launch window covers the moment the process starts; this is the
/// hand-off. It holds the mark on the app's background, fills the screen with
/// the accent, and gets out of the way — so the first thing Flutter draws is the
/// app arriving rather than a flash of empty surface.
///
/// Deliberately short, and skipped entirely when the system has asked for less
/// motion.
class LaunchSplash extends StatefulWidget {
  const LaunchSplash({super.key, required this.child, this.onFinished});

  /// The app itself. Built underneath the splash from the first frame, so it is
  /// laid out and ready the moment the splash leaves.
  final Widget child;

  /// Called once the splash has finished. A sheet that needs a Navigator can
  /// wait on this rather than appearing over the splash.
  final VoidCallback? onFinished;

  @override
  State<LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends State<LaunchSplash>
    with SingleTickerProviderStateMixin {
  static const Duration _total = Duration(milliseconds: 1500);

  // The three beats, as fractions of the whole: the mark arrives, the accent
  // washes across, and then the splash leaves to reveal the UI.
  static const double _markEnd = 0.30;
  static const double _washEnd = 0.78;

  late final AnimationController _controller;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total)
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) _finish();
      });

    if (AstryxMotion.reduced) {
      // Nothing to watch: show the app.
      _done = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => widget.onFinished?.call());
    } else {
      _controller.forward();
    }
  }

  void _finish() {
    if (!mounted || _done) return;
    setState(() => _done = true);
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;

    final AstryxColors c = context.astryx;
    final Size size = MediaQuery.sizeOf(context);
    // A radius that reaches every corner from the centre, whatever the shape.
    final double maxRadius =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;

    return Stack(
      children: <Widget>[
        widget.child,
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? _) {
              final double t = _controller.value;
              final double mark = Curves.easeOut
                  .transform((t / _markEnd).clamp(0.0, 1.0));
              final double wash = Curves.easeInOutCubic.transform(
                ((t - _markEnd) / (_washEnd - _markEnd)).clamp(0.0, 1.0),
              );
              // The splash itself leaves once the wash has landed, and the UI is
              // what is left behind it.
              final double leave = Curves.easeIn
                  .transform(((t - _washEnd) / (1 - _washEnd)).clamp(0.0, 1.0));

              return Opacity(
                opacity: 1 - leave,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(child: ColoredBox(color: c.backgroundBody)),
                    Center(
                      child: Opacity(
                        opacity: mark,
                        child: Transform.scale(
                          scale: 0.85 + 0.15 * mark,
                          child: const BrandMark(size: 96),
                        ),
                      ),
                    ),
                    // The accent, washing out from behind the mark until it has
                    // filled the screen.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ClipPath(
                          clipper: _CircleClipper(
                            center: Offset(size.width / 2, size.height / 2),
                            radius: maxRadius * wash,
                          ),
                          child: ColoredBox(color: c.accent),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A circle centred where the mark is, grown by the wash.
class _CircleClipper extends CustomClipper<Path> {
  const _CircleClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(_CircleClipper oldClipper) =>
      oldClipper.radius != radius || oldClipper.center != center;
}
