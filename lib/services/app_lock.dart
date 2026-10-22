import 'package:flutter/foundation.dart';
import '../util/redact.dart';
import 'package:local_auth/local_auth.dart';

/// Whether the device will vouch for the person holding it.
///
/// Best effort throughout. A phone with no reader, nothing enrolled, or a
/// plugin that will not start must not lock anyone out of their own mail —
/// [available] is what the setting checks before it offers to turn itself on,
/// so the switch can say "this device cannot" rather than silently doing
/// nothing.
abstract final class AppLock {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Whether there is anything here to ask for.
  static Future<bool> available() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return true;
    } catch (error) {
      debugPrint('Ace Mail: no device authentication (${Redact.safe(error)})');
      return false;
    }
  }

  /// Asks, and reports whether the device said yes.
  ///
  /// A refusal (the user cancelled, a finger did not match) comes back as false.
  /// A device that cannot answer at all also comes back as false — being unable
  /// to ask is not a reason to let someone in, but it is a reason to say so
  /// rather than to throw at the caller.
  static Future<bool> unlock() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Ace Mail',
        // The device passcode is a fallback, not a hole: it is the same secret
        // the phone already asks for, and without it a scratched sensor locks
        // you out of your own mail.
        biometricOnly: false,
        // The system may background the app mid-prompt. Retrying on return is
        // better than failing an unlock because a notification arrived.
        persistAcrossBackgrounding: true,
      );
    } catch (error) {
      debugPrint('Ace Mail: unlock could not be asked for (${Redact.safe(error)})');
      return false;
    }
  }
}
