import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Certificate validation is not a setting, and this is the test that keeps it
/// that way.
///
/// A TLS check that can be turned off is off when it matters. The way it gets
/// turned off in practice is a callback added during an afternoon of debugging
/// and never removed — so the cheapest guard is to fail the build the moment
/// one appears.
void main() {
  test('nothing in lib/ disables certificate validation', () {
    final List<String> offenders = <String>[];

    for (final FileSystemEntity entity
        in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Comments are stripped first, so the rule can be written down next to
      // the code it governs without tripping this test.
      final String source = entity
          .readAsStringSync()
          .split('\n')
          .where((String line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      for (final String needle in <String>[
        'badCertificateCallback',
        'onBadCertificate',
        'HttpOverrides',
        'setTrustedCertificates',
        'certificateErrors',
        'ConnectionTask',
      ]) {
        if (source.contains(needle)) {
          offenders.add('${entity.path} mentions $needle');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'TLS certificate validation must stay on, in every build',
    );
  });

  test('the protocol log is off, so a password cannot be logged', () {
    // `isLogEnabled: true` prints the whole LOGIN command, password included.
    final String service =
        File('lib/services/mail_service.dart').readAsStringSync();
    expect(service, contains('isLogEnabled: false'));
    expect(service, isNot(contains('isLogEnabled: true')));
  });

  test('every connection is secure', () {
    final String service =
        File('lib/services/mail_service.dart').readAsStringSync();
    // IMAP: secure from the first byte. SMTP: implicit TLS on 465, STARTTLS
    // otherwise — both branches present.
    expect(service, contains('isSecure: true'));
    expect(service, contains('startTls()'));
  });
}
