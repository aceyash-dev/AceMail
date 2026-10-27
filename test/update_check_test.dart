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
}
