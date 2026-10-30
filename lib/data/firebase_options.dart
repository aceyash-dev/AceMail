import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase, when this build has been given a project.
///
/// `flutterfire configure` writes a `firebase_options.dart` with a project's
/// keys in it. That file is deliberately not in this repository: the keys are
/// per-project, they differ per platform, and a repository is not where they
/// belong. So the options are read from the build instead — the same mechanism
/// the Google client and the release signing already use — and a build with
/// nothing configured starts exactly as it did before Firebase existed.
///
/// To wire a project in:
///
/// ```
/// flutterfire configure --project=tab-gl
/// ```
///
/// then either keep its `firebase_options.dart` and return it from
/// [DefaultFirebaseOptions.currentPlatform], or pass the values at build time:
///
/// ```
/// flutter build apk \
///   --dart-define=FIREBASE_API_KEY=... \
///   --dart-define=FIREBASE_APP_ID=... \
///   --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
///   --dart-define=FIREBASE_PROJECT_ID=tab-gl \
///   --dart-define=FIREBASE_STORAGE_BUCKET=tab-gl.appspot.com
/// ```
abstract final class FirebaseOptions_ {
  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const String iosBundleId =
      String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  /// Whether this build knows about a project at all.
  static bool get configured =>
      apiKey.isNotEmpty && appId.isNotEmpty && projectId.isNotEmpty;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        storageBucket: storageBucket,
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          storageBucket: storageBucket,
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          storageBucket: storageBucket,
          iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
        );
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        return FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          storageBucket: storageBucket,
        );
    }
  }
}

/// Starts Firebase, or says why it did not.
///
/// Never throws. An app whose mail works must not refuse to open because a
/// backend it does not need yet was unreachable — that is the failure mode this
/// whole function exists to prevent.
Future<bool> startFirebase() async {
  if (!FirebaseOptions_.configured) {
    debugPrint('Ace Mail: Firebase is not configured in this build.');
    return false;
  }
  try {
    await Firebase.initializeApp(options: FirebaseOptions_.currentPlatform);
    return true;
  } catch (error) {
    debugPrint('Ace Mail: Firebase did not start ($error)');
    return false;
  }
}
