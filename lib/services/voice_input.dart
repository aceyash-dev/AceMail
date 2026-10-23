import 'dart:async';

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

  /// How long to wait for an answer before giving up.
  ///
  /// The device's speech app is another window: it can be swiped away, or the
  /// process can be killed while it is open, and a channel call whose result is
  /// never sent would leave the microphone spinning for ever. Two minutes is
  /// longer than anyone speaks into a search box.
  static const Duration timeout = Duration(minutes: 2);

  /// Asks the device to listen, and returns what it heard.
  ///
  /// Null means the person cancelled, or said nothing — the two are the same
  /// from here, and neither is an error.
  static Future<String?> listen() async {
    try {
      final String? heard =
          await _channel.invokeMethod<String>('listen').timeout(timeout);
      final String words = heard?.trim() ?? '';
      return words.isEmpty ? null : words;
    } on PlatformException catch (error) {
      throw VoiceInputException(
        error.code == 'no_recogniser'
            ? 'This device has no speech recogniser installed.'
            : 'The microphone could not be used.',
      );
    } on TimeoutException {
      // Nothing came back. The microphone stops saying it is listening.
      return null;
    } on MissingPluginException {
      // A platform with no channel at all (desktop, the web). Said plainly,
      // because a microphone that does nothing is worse than one that says why.
      throw const VoiceInputException(
        'Voice search is not available on this platform.',
      );
    }
  }
}
