import 'package:flutter/material.dart';

import '../theme/astryx_tokens.dart';

/// Material 3 Expressive "fade through", used for every pushed screen.
///
/// The incoming screen fades in while scaling up from 92%, and the screen being
/// covered fades out on the way. The emphasised easing is Material's, and the
/// durations are the expressive ones rather than the shorter defaults.
Route<T> aceRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        final CurvedAnimation enter = CurvedAnimation(
          parent: animation,
          curve: AstryxMotion.emphasizedDecelerate,
          reverseCurve: AstryxMotion.emphasizedAccelerate,
        );
        final CurvedAnimation leave = CurvedAnimation(
          parent: secondaryAnimation,
          curve: AstryxMotion.emphasizedAccelerate,
        );

        return FadeTransition(
          // Fades this screen out if something is pushed on top of it.
          opacity: Tween<double>(begin: 1, end: 0).animate(leave),
          child: FadeTransition(
            opacity: enter,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(enter),
              child: child,
            ),
          ),
        );
      },
    );
