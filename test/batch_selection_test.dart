import 'package:ace_mail/models/message_summary.dart';
import 'package:ace_mail/state/mail_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

void main() {
  group('deleting or archiving a selection', () {
    test('sends the picked messages as one batch, not one call each', () async {
      final FakeTransport transport = FakeTransport()
        ..uids.addAll(<int>[1, 2, 3, 4, 5]);
      final MailSession session = MailSession(
        account: accountA,
        password: 'p',
        transport: transport,
      );
      await session.connect();

      for (final int uid in <int>[1, 2, 3]) {
        session.toggleSelect(uid);
      }
      await session.deleteSelected(permanently: true);

      expect(transport.batchSizes, <int>[3]);
      expect(session.messages.map((MessageSummary m) => m.uid), <int>[4, 5]);
      expect(session.selected, isEmpty);
    });

    test('archive is also one batch', () async {
      final FakeTransport transport = FakeTransport()
        ..uids.addAll(<int>[1, 2, 3]);
      final MailSession session = MailSession(
        account: accountA,
        password: 'p',
        transport: transport,
      );
      await session.connect();

      session.toggleSelect(1);
      session.toggleSelect(2);
      await session.archiveSelected();

      expect(transport.batchSizes, <int>[2]);
      expect(session.messages.map((MessageSummary m) => m.uid), <int>[3]);
    });

    test('an empty selection does nothing', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(<int>[1]);
      final MailSession session = MailSession(
        account: accountA,
        password: 'p',
        transport: transport,
      );
      await session.connect();

      await session.deleteSelected(permanently: true);

      expect(transport.batchSizes, isEmpty);
      expect(session.messages.length, 1);
    });
  });
}
