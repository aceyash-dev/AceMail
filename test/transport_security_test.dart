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
    // Neither transport is secure from the first byte on every port: 993 and
    // 465 speak TLS immediately, and everything else starts plain and is
    // upgraded with STARTTLS before a password is sent. What has to hold is that
    // both decide by the port and both upgrade — and that no branch leaves a
    // plain connection with credentials going into it.
    expect(service, contains('final bool implicitTls = account.imapPort == 993'));
    expect(service, contains('final bool implicitTls = account.smtpPort == 465'));
    expect(RegExp('isSecure: implicitTls').allMatches(service).length, 2);
    expect(RegExp(r'startTls\(\)').allMatches(service).length, 2);
    // The one thing that would make all of it pointless.
    expect(service, isNot(contains('badCertificateCallback')));
  });
}
