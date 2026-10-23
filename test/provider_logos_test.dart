import 'dart:io';

import 'package:ace_mail/data/mail_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Every provider logo is a file this app has to be able to parse.
///
/// The iCloud one was a CloudFlare logo — the wrong artwork, mislabelled at the
/// source — and nothing noticed, because an asset that exists and is broken
/// only shows up as a blank tile. A logo is XML; malformed XML is checkable.
void main() {
  test('every provider logo parses', () {
    for (final MailProvider provider in kProviderChoices) {
      final File file = File(provider.logo);
      expect(file.existsSync(), isTrue, reason: '${provider.logo} is missing');

      final String source = file.readAsStringSync();
      final XmlDocument document;
      try {
        document = XmlDocument.parse(source);
      } on XmlException catch (error) {
        fail('${provider.logo} is not valid XML: ${error.message}');
      }

      final XmlElement root = document.rootElement;
      expect(root.name.local, 'svg', reason: provider.logo);

      // It has to be able to scale: without a viewBox, flutter_svg lays the
      // artwork out at its own pixel size inside whatever box it is given.
      expect(
        root.getAttribute('viewBox'),
        isNotNull,
        reason: '${provider.logo} has no viewBox',
      );
      expect(
        root.findElements('*').where((XmlElement e) =>
            e.name.local == 'path' || e.name.local == 'g').isNotEmpty,
        isTrue,
        reason: '${provider.logo} draws nothing',
      );
    }
  });

  test('no two providers share a logo file', () {
    final Set<String> logos = kProviderChoices
        .map((MailProvider provider) => provider.logo)
        .toSet();
    expect(logos, hasLength(kProviderChoices.length));
  });
}
