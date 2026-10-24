import 'package:ace_mail/data/preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the marker remembers the namespace it was read in', () async {
    // A UID means nothing without the mailbox it came from. Saving one without
    // the other is what let a recreated mailbox go silent.
    final Preferences prefs = Preferences();
    await prefs.setLastSeenUid('a@b.com', 85000, validity: 12);

    expect(prefs.lastSeenUid('a@b.com'), 85000);
    expect(prefs.lastSeenUidValidity('a@b.com'), 12);
  });

  test('an unknown mailbox has no namespace', () {
    final Preferences prefs = Preferences();
    expect(prefs.lastSeenUid('nobody@example.com'), 0);
    expect(prefs.lastSeenUidValidity('nobody@example.com'), 0);
  });

  test('the address is matched however it is written', () async {
    final Preferences prefs = Preferences();
    await prefs.setLastSeenUid('Someone@Example.com', 5, validity: 3);
    expect(prefs.lastSeenUidValidity('someone@example.com'), 3);
  });

  test('a saved UID can be updated without losing the namespace', () async {
    final Preferences prefs = Preferences();
    await prefs.setLastSeenUid('a@b.com', 10, validity: 7);
    await prefs.setLastSeenUid('a@b.com', 11);
    expect(prefs.lastSeenUid('a@b.com'), 11);
    expect(prefs.lastSeenUidValidity('a@b.com'), 7);
  });
}
