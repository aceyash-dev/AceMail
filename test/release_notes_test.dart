import 'package:ace_mail/widgets/whats_new.dart';
import 'package:flutter_test/flutter_test.dart';

/// The changelog lookup.
///
/// The bug this replaces: the sheet compared version *names*, so 0.5.1+33 to
/// 0.5.1+34 — a whole new section of notes — announced nothing at all.
void main() {
  const String changelog = '''
## 0.5.1+34

### Added
- The search bar has a microphone.

## 0.5.1

### Fixed
- An older section.

## 0.5.0+30 — a title, because some headings have one

### Fixed
- Older still.
''';

  test('finds the section for the running build', () {
    expect(
      ReleaseNotes.sectionFor(changelog, '0.5.1+34'),
      contains('microphone'),
    );
  });

  test('a build is not confused with the section under it', () {
    expect(
      ReleaseNotes.sectionFor(changelog, '0.5.1+34'),
      isNot(contains('older section')),
    );
    // And asking for the name alone gives the name's own section, not the
    // newest one that starts with it.
    expect(
      ReleaseNotes.sectionFor(changelog, '0.5.1'),
      contains('older section'),
    );
  });

  test('a heading with a title after the version still matches', () {
    expect(
      ReleaseNotes.sectionFor(changelog, '0.5.0+30'),
      contains('Older still'),
    );
  });

  test('an unknown version is null, not the wrong section', () {
    expect(ReleaseNotes.sectionFor(changelog, '9.9.9'), isNull);
    expect(ReleaseNotes.sectionFor(changelog, '0.5'), isNull);
    expect(ReleaseNotes.sectionFor(changelog, ''), isNull);
  });

  test('a section stops at the next heading', () {
    final String? body = ReleaseNotes.sectionFor(changelog, '0.5.1');
    expect(body, contains('An older section'));
    expect(body, isNot(contains('Older still')));
  });
}
