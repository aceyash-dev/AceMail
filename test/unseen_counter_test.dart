import 'package:ace_mail/state/mail_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

/// The count in the greeting and in the rail badge.
///
/// It comes from the server's folder listing, which is only as fresh as the
/// last one. These are the cases where the app used to keep showing the old
/// number after the mail behind it had already moved.
void main() {
  Future<MailSession> openSession(FakeTransport transport) async {
    final MailSession session = MailSession(
      account: accountA,
      password: 'p',
      transport: transport,
    );
    await session.connect();
    return session;
  }

  FakeTransport inbox(int count) {
    final FakeTransport transport = FakeTransport()
      ..uids.addAll(uidRange(count))
      ..unread.addAll(uidRange(count))
      ..inboxUnseen = count;
    return transport;
  }

  group('the unread count', () {
    test('drops when an unread message is opened', () async {
      final MailSession session = await openSession(inbox(3));
      expect(session.inboxUnseen, 3);

      await session.open(session.messages.first);

      expect(session.inboxUnseen, 2);
      expect(session.messages.first.isSeen, isTrue);
    });

    test('comes back when the open message is marked unread', () async {
      final MailSession session = await openSession(inbox(3));
      await session.open(session.messages.first);
      expect(session.inboxUnseen, 2);

      await session.markOpenUnread();

      expect(session.inboxUnseen, 3);
    });

    test('does not count the same message twice', () async {
      final MailSession session = await openSession(inbox(3));
      await session.open(session.messages.first);

      // Already unread on the server as far as the app knows, so this must not
      // add a second one.
      await session.markOpenUnread();
      await session.markOpenUnread();

      expect(session.inboxUnseen, 3);
    });

    test('drops when a message is marked read from the list', () async {
      final MailSession session = await openSession(inbox(4));

      await session.markRead(session.messages.first);

      expect(session.inboxUnseen, 3);
    });

    test('drops when an unread message is deleted', () async {
      final MailSession session = await openSession(inbox(2));

      await session.delete(session.messages.first);

      expect(session.inboxUnseen, 1);
    });

    test('does not move for a message that was already read', () async {
      final FakeTransport transport = inbox(3)
        ..unread.remove(1); // the first message has been read already
      final MailSession session = await openSession(transport);
      expect(session.inboxUnseen, 3);

      await session.delete(session.messages.first);

      expect(session.inboxUnseen, 3);
    });

    test('never goes below zero', () async {
      // The server said zero and the app still shows an unread row: a local
      // subtraction must not leave the folder owing mail.
      final FakeTransport transport = FakeTransport()
        ..uids.addAll(uidRange(1))
        ..unread.add(1)
        ..inboxUnseen = 0;
      final MailSession session = await openSession(transport);

      await session.open(session.messages.first);

      expect(session.inboxUnseen, 0);
    });

    test('moves on the batch path too, once the server agrees', () async {
      final MailSession session = await openSession(inbox(5));
      session.toggleSelect(session.messages[0].uid);
      session.toggleSelect(session.messages[1].uid);

      await session.archiveSelected();

      expect(session.inboxUnseen, 3);
    });

    test('a failed batch leaves the count where it was', () async {
      final FakeTransport transport = inbox(5)..failMove = true;
      final MailSession session = await openSession(transport);
      session.toggleSelect(session.messages.first.uid);

      await session.archiveSelected();

      expect(session.inboxUnseen, 5);
    });
  });
}
