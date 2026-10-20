import 'package:ace_mail/data/preferences.dart';
import 'package:ace_mail/models/swipe_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('swipe settings', () {
    test('default to read/unread one way and archive the other', () {
      final Preferences prefs = Preferences();
      expect(prefs.swipeStart, SwipeAction.toggleRead);
      expect(prefs.swipeEnd, SwipeAction.archive);
    });

    test('every action has a label for the settings row', () {
      for (final SwipeAction action in SwipeAction.values) {
        expect(action.label, isNotEmpty);
      }
    });

    test('setting a swipe action applies and notifies', () async {
      final Preferences prefs = Preferences();
      int notifications = 0;
      prefs.addListener(() => notifications++);

      await prefs.setSwipeStart(SwipeAction.trash);
      await prefs.setSwipeEnd(SwipeAction.none);

      expect(prefs.swipeStart, SwipeAction.trash);
      expect(prefs.swipeEnd, SwipeAction.none);
      expect(notifications, 2);
    });
  });

  group('message view', () {
    test('defaults to formatted, because that is what most mail is', () {
      expect(Preferences().messageView, MessageView.formatted);
    });

    test('can be switched to plain text', () async {
      final Preferences prefs = Preferences();
      await prefs.setMessageView(MessageView.plainText);
      expect(prefs.messageView, MessageView.plainText);
    });
  });
}
