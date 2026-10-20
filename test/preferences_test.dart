import 'package:ace_mail/data/preferences.dart';
import 'package:flutter_test/flutter_test.dart';

/// The keychain is not available in a test, which is exactly the case
/// [Preferences] is built to survive: every read falls back, every write is
/// best effort, and the value still applies for the session.
void main() {
  group('Preferences', () {
    test('defaults are the privacy-first ones', () {
      final Preferences prefs = Preferences();

      expect(prefs.showAvatars, isFalse, reason: 'Gravatar is opt-in');
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

      expect(prefs.showAvatars, isFalse);
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
