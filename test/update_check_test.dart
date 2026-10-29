import 'package:ace_mail/services/update_check.dart';
import 'package:flutter_test/flutter_test.dart';

/// What GitHub answers for `/releases/latest`, trimmed to the fields that matter.
const String captured = '''
{
  "tag_name": "v0.6.0+83",
  "name": "0.6.0+83",
  "body": "### Added\\n- Address suggestions while typing.",
  "html_url": "https://github.com/tab-gl/AceMail/releases/tag/v0.6.0%2B83",
  "published_at": "2026-10-28T09:00:00Z",
  "draft": false
}
''';

void main() {
  group('reading a release', () {
    test('takes the tag, the notes and the page', () {
      final UpdateRelease? release = UpdateCheck.parse(captured);
      expect(release, isNotNull);
      expect(release!.version, '0.6.0+83');
      expect(release.name, '0.6.0+83');
      expect(release.notes, contains('Address suggestions'));
      expect(release.url, contains('releases/tag'));
      expect(release.published, DateTime.utc(2026, 10, 28, 9));
      expect(release.hasNotes, isTrue);
    });

    test('a tag is the same with or without its v', () {
      expect(UpdateCheck.versionOf('v0.6.0+82'), '0.6.0+82');
      expect(UpdateCheck.versionOf('V0.6.0+82'), '0.6.0+82');
      expect(UpdateCheck.versionOf('0.6.0+82'), '0.6.0+82');
    });

    test('anything that is not a release is null, not a guess', () {
      expect(UpdateCheck.parse('not json'), isNull);
      expect(UpdateCheck.parse('{"message":"Not Found"}'), isNull);
      expect(UpdateCheck.parse('[]'), isNull);
      expect(UpdateCheck.parse('{"tag_name":""}'), isNull);
    });

    test('a release with no notes says so rather than pretending', () {
      final UpdateRelease? release = UpdateCheck.parse(
        '{"tag_name":"v0.6.0+90","body":""}',
      );
      expect(release?.hasNotes, isFalse);
      expect(release?.name, '0.6.0+90');
    });
  });

  group('is it newer', () {
    test('a higher build number is an update', () {
      expect(UpdateCheck.isNewer('0.6.0+83', '0.6.0+82'), isTrue);
      expect(UpdateCheck.isNewer('0.6.0+82', '0.6.0+82'), isFalse);
      expect(UpdateCheck.isNewer('0.6.0+81', '0.6.0+82'), isFalse);
    });

    test('a higher version name is an update, whatever the build', () {
      expect(UpdateCheck.isNewer('0.7.0+1', '0.6.0+999'), isTrue);
      expect(UpdateCheck.isNewer('0.6.1', '0.6.0+82'), isTrue);
      expect(UpdateCheck.isNewer('0.6.0', '0.6.0+82'), isFalse);
    });

    test('0.6 and 0.6.0 are the same version', () {
      expect(UpdateCheck.isNewer('0.6', '0.6.0'), isFalse);
      expect(UpdateCheck.isNewer('0.6.0', '0.6'), isFalse);
    });

    test('a version that cannot be read is never an update', () {
      expect(UpdateCheck.isNewer('latest', '0.6.0+82'), isFalse);
      expect(UpdateCheck.isNewer('', '0.6.0+82'), isFalse);
      expect(UpdateCheck.isNewer('0.6.0+82', ''), isFalse);
    });
  });

  group('the list fallback', () {
    // `/latest` skips drafts and pre-releases, and answers with something older
    // — or nothing — when the newest release is one. That is the shape of a
    // check that has quietly stopped working, so the list is asked as well.
    test('the newest real release wins', () {
      final UpdateRelease? release = UpdateCheck.parseList('''
          [{"tag_name":"v0.6.1","name":"v0.6.1","body":"notes",
            "html_url":"https://example.test/1","draft":false,"prerelease":false},
           {"tag_name":"v0.6.0+91","name":"","body":"","draft":false,"prerelease":false}]
          ''');

      expect(release, isNotNull);
      expect(release!.version, '0.6.1');
      expect(release.notes, 'notes');
      expect(release.url, 'https://example.test/1');
    });

    test('drafts and pre-releases are skipped', () {
      final UpdateRelease? release = UpdateCheck.parseList('''
          [{"tag_name":"apk-latest","prerelease":true},
           {"tag_name":"v0.7.0","draft":true},
           {"tag_name":"v0.6.1","prerelease":false,"draft":false}]
          ''');

      expect(release?.version, '0.6.1');
    });

    test('a list of nothing usable is null, not a guess', () {
      expect(UpdateCheck.parseList('[]'), isNull);
      expect(UpdateCheck.parseList('not json'), isNull);
      expect(UpdateCheck.parseList('{"tag_name":"v1.0.0"}'), isNull);
      expect(UpdateCheck.parseList('[{"tag_name":""}]'), isNull);
    });

    test('0.6.1 is newer than a 0.6.0 build number, and equal to itself', () {
      expect(UpdateCheck.isNewer('0.6.1', '0.6.0+91'), isTrue);
      expect(UpdateCheck.isNewer('0.6.1', '0.6.1+92'), isFalse);
    });
  });

  group('notes a markdown view can render', () {
    test('an HTML accordion becomes headings and bullets', () {
      // Older release bodies were written for GitHub's renderer, and arrived on
      // a phone as literal <details> text.
      final String plain = UpdateCheck.plainNotes(
        '### What changed in 0.6.1+92\n\n'
        '<details>\n<summary><b>Fixed</b> (6)</summary>\n\n'
        '- **A fix.** The detail.\n\n</details>\n',
      );

      expect(plain, isNot(contains('<details>')));
      expect(plain, isNot(contains('<summary>')));
      expect(plain, isNot(contains('<b>')));
      expect(plain, contains('#### Fixed (6)'));
      expect(plain, contains('**A fix.**'));
    });

    test('markdown that was never HTML comes through untouched', () {
      const String body = '#### Fixed (1)\n\n- **A fix.** The detail.\n';
      expect(UpdateCheck.plainNotes(body).trim(), body.trim());
    });

    test('runs of blank lines collapse', () {
      expect(UpdateCheck.plainNotes('a\n\n\n\n\nb'), 'a\n\nb');
    });
  });
}
