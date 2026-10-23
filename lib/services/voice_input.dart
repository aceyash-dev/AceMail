import 'package:flutter/services.dart';

/// The device cannot listen.
class VoiceInputException implements Exception {
  const VoiceInputException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The microphone, borrowed from the device.
///
/// Speech recognition is not something this app does. It asks the device's own
/// speech app to listen and hands back text — on a phone with Google services
/// that is Google's recogniser, which is the one people expect behind a
/// microphone in a search bar.
///
/// Two consequences worth knowing, and they are the reason this is a channel
/// rather than a package that records:
///
/// * **The audio never reaches Ace Mail.** It goes to whichever speech app the
///   device has, and what comes back is a string.
/// * **The app never asks for the microphone permission**, because it never
///   records anything itself. There is no `RECORD_AUDIO` in the manifest, and a
///   search bar that demands microphone access to look for a word is a bad
///   trade.
abstract final class VoiceInput {
  static const MethodChannel _channel = MethodChannel('app.tab.mail/voice');

  /// Asks the device to listen, and returns what it heard.
  ///
  /// Null means the person cancelled, or said nothing — the two are the same
  /// from here, and neither is an error.
  static Future<String?> listen() async {
    try {
      final String? heard = await _channel.invokeMethod<String>('listen');
      final String words = heard?.trim() ?? '';
      return words.isEmpty ? null : words;
    } on PlatformException catch (error) {
      throw VoiceInputException(
        error.code == 'no_recogniser'
            ? 'This device has no speech recogniser installed.'
            : 'The microphone could not be used.',
      );
    } on MissingPluginException {
      // Not Android, or a build without the channel.
      throw const VoiceInputException('Voice search needs Android.');
    }
  }
}
