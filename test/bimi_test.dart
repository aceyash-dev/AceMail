import 'package:ace_mail/services/bimi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('logoFromRecord', () {
    test('pulls the logo out of a real record', () {
      expect(
        BimiResolver.logoFromRecord(
          'v=BIMI1; l=https://example.com/logo.svg; a=https://example.com/vmc.pem',
        ),
        'https://example.com/logo.svg',
      );
    });

    test('accepts a record with no authority', () {
      expect(
        BimiResolver.logoFromRecord('v=BIMI1; l=https://example.com/logo.svg'),
        'https://example.com/logo.svg',
      );
    });

    test('tolerates loose spacing and casing', () {
      expect(
        BimiResolver.logoFromRecord('v=BIMI1;  L = https://a.example/l.svg '),
        isNull,
        reason: 'the key is case-insensitive but the separator is not "L ="',
      );
      expect(
        BimiResolver.logoFromRecord('v=BIMI1;L=https://a.example/l.svg'),
        'https://a.example/l.svg',
      );
    });

    test('refuses anything that is not https', () {
      for (final String record in <String>[
        'v=BIMI1; l=http://example.com/logo.svg',
        'v=BIMI1; l=javascript:alert(1)',
        'v=BIMI1; l=file:///etc/passwd',
        'v=BIMI1; l=data:image/svg+xml;base64,PHN2Zz4=',
      ]) {
        expect(
          BimiResolver.logoFromRecord(record),
          isNull,
          reason: record,
        );
      }
    });

    test('refuses an https URL with no host', () {
      expect(BimiResolver.logoFromRecord('v=BIMI1; l=https:///logo.svg'), isNull);
    });

    test('an empty l= is not a logo', () {
      expect(BimiResolver.logoFromRecord('v=BIMI1; l=; a=x'), isNull);
    });

    test('a record with no logo at all returns null', () {
      expect(BimiResolver.logoFromRecord('v=BIMI1'), isNull);
      expect(BimiResolver.logoFromRecord(''), isNull);
    });
  });

  group('parseRecord', () {
    test('reads a DNS-over-HTTPS answer', () {
      const String json = '{"Status":0,"Answer":['
          '{"name":"default._bimi.example.com","type":16,"TTL":300,'
          '"data":"\\"v=BIMI1; l=https://example.com/logo.svg\\""}]}';
      expect(BimiResolver.parseRecord(json), 'https://example.com/logo.svg');
    });

    test('skips answers that are not records', () {
      const String json = '{"Status":0,"Answer":['
          '{"name":"x","type":16,"data":"\\"not a bimi record\\""},'
          '{"name":"x","type":16,"data":"\\"v=BIMI1; l=https://ok.example/l.svg\\""}]}';
      expect(BimiResolver.parseRecord(json), 'https://ok.example/l.svg');
    });

    test('a domain with no record is not an error', () {
      expect(BimiResolver.parseRecord('{"Status":3}'), isNull);
      expect(BimiResolver.parseRecord('{}'), isNull);
    });

    test('garbage does not throw', () {
      expect(() => BimiResolver.parseRecord('not json'), throwsFormatException);
    });
  });
}
