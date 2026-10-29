import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

/// A pushed screen, with the transition the platform's own apps use.
///
/// This was a hand-built fade-and-scale, drawn from Material's expressive
/// motion. It was pretty and it was wrong: on iOS a screen that fades in over
/// another one is not what any system app does, and the back-swipe from the left
/// edge — the gesture people have in their thumbs — came with it only if the
/// route was a Cupertino one.
///
/// So it is a `CupertinoPageRoute`: the incoming screen slides in from the right,
/// the one underneath slides a third as far and dims, the shadow falls between
/// them, and on iOS the edge swipe works. Reduce-motion is honoured by the
/// platform itself, which drops the slide for a cross-fade.
Route<T> aceRoute<T>(Widget page) => CupertinoPageRoute<T>(
      builder: (BuildContext context) => page,
      // Full-screen on iOS gives the standard transition; on the platforms
      // where it does not exist the flag is ignored.
      fullscreenDialog: false,
    );
