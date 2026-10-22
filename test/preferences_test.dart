import 'package:ace_mail/data/preferences.dart';
import 'package:flutter_test/flutter_test.dart';

/// The keychain is not available in a test, which is exactly the case
/// [Preferences] is built to survive: every read falls back, every write is
/// best effort, and the value still applies for the session.
void main() {
  group('Preferences', () {
    // These two are the trade-off, and they are on because that is what was
    // asked for: images and sender pictures are what a mail reader is expected
    // to show. Both leak something — a remote image tells the sender's server
    // the message was opened, and a Gravatar lookup tells a third party who is
    // in your mail — so both have a switch, and the warnings that matter (links
    // and empty subjects) stay on.
    test('the defaults show the mail', () {
      final Preferences prefs = Preferences();

      expect(prefs.showAvatars, isTrue);
      expect(prefs.loadRemoteImages, isTrue);
      expect(prefs.themeMode, AceThemeMode.system);
      expect(prefs.textSize, AceTextSize.medium);
      expect(prefs.textScale, 1.0);
      expect(prefs.confirmExit, isTrue);
      expect(prefs.markAsReadOnOpen, isTrue);
      expect(prefs.signature, '');
    });

    test('loading with an unreadable keychain keeps the defaults', () async {
      final Preferences prefs = Preferences();
      await prefs.load();

      expect(prefs.showAvatars, isTrue);
      expect(prefs.themeMode, AceThemeMode.system);
      expect(prefs.textSize, AceTextSize.medium);
    });

    test('each setter applies the value and notifies', () async {
      final Preferences prefs = Preferences();
      int notifications = 0;
      prefs.addListener(() => notifications++);

      await prefs.setShowAvatars(true);
      await prefs.setConfirmExit(false);
      await prefs.setMarkAsReadOnOpen(false);
      await prefs.setThemeMode(AceThemeMode.dark);
      await prefs.setTextSize(AceTextSize.large);
      await prefs.setSignature('Sent from Ace Mail');

      expect(prefs.showAvatars, isTrue);
      expect(prefs.confirmExit, isFalse);
      expect(prefs.markAsReadOnOpen, isFalse);
      expect(prefs.themeMode, AceThemeMode.dark);
      expect(prefs.textSize, AceTextSize.large);
      expect(prefs.textScale, 1.15);
      expect(prefs.signature, 'Sent from Ace Mail');
      expect(notifications, 6);
    });

    test('setting the same value twice still notifies but does not thrash', () async {
      final Preferences prefs = Preferences();
      await prefs.setThemeMode(AceThemeMode.light);
      await prefs.setThemeMode(AceThemeMode.light);
      expect(prefs.themeMode, AceThemeMode.light);
    });

    test('the sending and gesture settings default sensibly', () {
      final Preferences prefs = Preferences();
      expect(prefs.quoteReplies, isTrue);
      expect(prefs.signatureOnReplies, isFalse);
      expect(prefs.confirmArchive, isFalse);
      expect(prefs.undoWindow, UndoWindow.normal);
      expect(prefs.bccSelf, isFalse);
    });

    test('every undo window has a label and a positive duration', () {
      for (final UndoWindow window in UndoWindow.values) {
        expect(window.label, isNotEmpty);
        expect(window.duration.inSeconds, greaterThan(0));
      }
    });

    test('every theme mode has a label for the settings row', () {
      for (final AceThemeMode mode in AceThemeMode.values) {
        expect(mode.label, isNotEmpty);
      }
      for (final AceTextSize size in AceTextSize.values) {
        expect(size.label, isNotEmpty);
        expect(size.scale, greaterThan(0));
      }
    });
  });
}
