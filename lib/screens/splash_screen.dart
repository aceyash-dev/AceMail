import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../widgets/astryx_widgets.dart';

/// Shown while the first mailbox is being opened.
///
/// Not a blank screen with a spinner: the shape-morph indicator, and a line
/// that changes as the wait goes on. The native launch window draws the same
/// background, so this reads as one continuous opening rather than a screen
/// that replaced another.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// Rotating, in a period voice, because a loading line that never changes
  /// stops being read after the first second.
  static const List<String> _lines = <String>[
    'Summoning thy letters from yonder server…',
    'Hark! Thy correspondence approacheth…',
    'The post doth ride, and rides swiftly…',
    'Gathering thy tidings anon…',
    'Prithee, a moment — thy missives are afoot…',
    'Lo! Thine inbox doth assemble itself…',
    'Swift as Mercury, thy letters come…',
    'Thy scrolls are yet in transit…',
    'The courier tarries but a breath…',
    'Fret not, good soul — thy mail is nigh…',
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted) setState(() => _index = (_index + 1) % _lines.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Scaffold(
      backgroundColor: c.backgroundBody,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const AceLoader(size: 68),
            const SizedBox(height: AstryxSpace.s8),
            // Sized, so the rotating lines do not shuffle the layout.
            SizedBox(
              height: 48,
              width: 320,
              child: AnimatedSwitcher(
                duration: AstryxMotion.medium,
                switchInCurve: AstryxMotion.emphasizedDecelerate,
                switchOutCurve: AstryxMotion.emphasizedAccelerate,
                transitionBuilder: (Widget child, Animation<double> anim) =>
                    FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.18),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  _lines[_index],
                  key: ValueKey<int>(_index),
                  textAlign: TextAlign.center,
                  style: AstryxText.body(c.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
