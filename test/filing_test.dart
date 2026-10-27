import 'package:ace_mail/models/mail_folder.dart';
import 'package:ace_mail/models/message_sort.dart';
import 'package:ace_mail/services/contacts.dart';
import 'package:ace_mail/models/message_summary.dart';
import 'package:ace_mail/state/mail_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

/// A mailbox with unread mail in it, and a junk folder.
class FilingTransport extends FakeTransport {
  FilingTransport({this.unseen = 0, super.junk = true});

  final int unseen;

  @override
  Future<List<MailFolder>> connect(String password) async {
    final List<MailFolder> folders = await super.connect(password);
    return <MailFolder>[
      for (final MailFolder folder in folders)
        folder.role == FolderRole.inbox
            ? folder.copyWith(unseen: unseen)
            : folder,
    ];
  }
}

MailSession sessionOn(FakeTransport transport) => MailSession(
      account: accountA,
      password: 'p',
      transport: transport,
    );

void main() {
  group('the page is worked out once', () {
    test('the same list comes back without filtering it again', () async {
      final FilingTransport transport = FilingTransport()..uids.addAll(uidRange(50));
      final MailSession session = sessionOn(transport);
      await session.connect();

      final List<MessageSummary> first = session.visibleMessages;
      expect(identical(session.visibleMessages, first), isTrue,
          reason: 'the list, the bar and the assistant all read this per frame');

      // A filter is a different answer, so it is a different list.
      session.setFilter(MessageFilter.unread);
      final List<MessageSummary> filtered = session.visibleMessages;
      expect(identical(filtered, first), isFalse);
      expect(identical(session.visibleMessages, filtered), isTrue);
    });

    test('blocking a sender shows at once, not on the next refresh', () async {
      final FilingTransport transport = FilingTransport()..uids.addAll(uidRange(3));
      final MailSession session = sessionOn(transport);
      await session.connect();

      final int before = session.visibleMessages.length;
      await Contacts.block('sender2@example.com');

      expect(session.visibleMessages.length, before - 1);
      await Contacts.unblock('sender2@example.com');
      expect(session.visibleMessages.length, before);
    });
  });

  group('select all', () {
    test('picks everything on the page, and says so', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(5));
      final MailSession session = sessionOn(transport);
      await session.connect();

      expect(session.allSelected, isFalse);
      session.selectAll();

      expect(session.selecting, isTrue);
      expect(session.selected.length, 5);
      expect(session.allSelected, isTrue);

      // Toggling one off is enough to make it not-all again.
      session.toggleSelect(session.visibleMessages.first.uid);
      expect(session.allSelected, isFalse);
    });

    test('an empty folder has nothing to pick', () async {
      final MailSession session = sessionOn(FakeTransport());
      await session.connect();

      session.selectAll();
      expect(session.selecting, isFalse);
      expect(session.allSelected, isFalse);
    });
  });

  group('mark all read', () {
    test('flags the whole folder and takes the count to zero', () async {
      final FilingTransport transport = FilingTransport(unseen: 5)
        ..uids.addAll(uidRange(5))
        ..unread.addAll(uidRange(5));
      final MailSession session = sessionOn(transport);
      await session.connect();

      expect(session.selectedFolder?.unseen, 5);
      final int marked = await session.markFolderRead();

      expect(marked, 5);
      expect(transport.markedReadBatches.single.length, 5);
      expect(session.selectedFolder?.unseen, 0);
      expect(
        session.messages.every((MessageSummary m) => m.isSeen),
        isTrue,
        reason: 'the rows say read, not just the count',
      );
    });

    test('a folder larger than one command goes in batches', () async {
      final FilingTransport transport = FilingTransport(unseen: 0)
        ..uids.addAll(uidRange(450));
      final MailSession session = sessionOn(transport);
      await session.connect();

      await session.markFolderRead();

      expect(transport.markedReadBatches.length, 3);
      expect(transport.markedReadBatches[0].length, 200);
      expect(transport.markedReadBatches[2].length, 50);
    });
  });

  group('filing', () {
    test('moves one message and takes the row with it', () async {
      final FilingTransport transport = FilingTransport(unseen: 3)
        ..uids.addAll(uidRange(3))
        ..unread.addAll(uidRange(3));
      final MailSession session = sessionOn(transport);
      await session.connect();

      final MessageSummary message = session.messages.first;
      await session.moveMessageTo(message, transport.archive);

      expect(transport.movedTo, 'Archive');
      expect(session.messages.any((MessageSummary m) => m.uid == message.uid),
          isFalse);
      expect(session.selectedFolder?.unseen, 2,
          reason: 'an unread message that left is one less waiting');
    });

    test('moves everything picked in one batch per folder', () async {
      final FilingTransport transport = FilingTransport()..uids.addAll(uidRange(4));
      final MailSession session = sessionOn(transport);
      await session.connect();

      session.selectAll();
      await session.moveSelectedTo(transport.archive);

      expect(transport.batchSizes, contains(4));
      expect(session.messages, isEmpty);
      expect(session.selecting, isFalse, reason: 'the picks leave with the rows');
    });

    test('refuses to file into the folder it is already in', () async {
      final FilingTransport transport = FilingTransport()..uids.addAll(uidRange(2));
      final MailSession session = sessionOn(transport);
      await session.connect();

      session.selectAll();
      await session.moveSelectedTo(transport.inbox);

      expect(session.errorMessage, contains('already in'));
      expect(session.messages.length, 2);
    });
  });

  group('spam', () {
    test('files a message into Junk', () async {
      final FilingTransport transport = FilingTransport()..uids.addAll(uidRange(2));
      final MailSession session = sessionOn(transport);
      await session.connect();

      await session.markSpam(session.messages.first);

      expect(transport.movedTo, 'Junk');
      expect(session.messages.length, 1);
    });

    test('says so when the account has no Junk folder', () async {
      final FakeTransport transport = FakeTransport(junk: false)
        ..uids.addAll(uidRange(2));
      final MailSession session = sessionOn(transport);
      await session.connect();

      await session.markSpam(session.messages.first);

      expect(session.errorMessage, contains('no Junk folder'));
      expect(transport.movedTo, isNull);
      expect(session.messages.length, 2);
    });

    test('empties the junk folder', () async {
      final FilingTransport transport = FilingTransport()..uids.addAll(uidRange(3));
      final MailSession session = sessionOn(transport);
      await session.connect();
      await session.openFolder(transport.junkFolder);

      await session.emptyJunk();

      expect(transport.deletedPermanently, isTrue);
      expect(transport.uids, isEmpty);
    });

    test('says so when there is no junk folder to empty', () async {
      final FakeTransport transport = FakeTransport(junk: false)
        ..uids.addAll(uidRange(2));
      final MailSession session = sessionOn(transport);
      await session.connect();

      await session.emptyJunk();

      expect(session.errorMessage, contains('no Junk folder'));
      expect(transport.uids.length, 2);
    });

    test('takes it back out of Junk into the inbox', () async {
      final FilingTransport transport = FilingTransport()..uids.addAll(uidRange(2));
      final MailSession session = sessionOn(transport);
      await session.connect();
      await session.openFolder(transport.junkFolder);

      expect(session.inJunk, isTrue);
      await session.markNotSpam(session.messages.first);

      expect(transport.movedTo, 'INBOX');
      expect(session.messages.length, 1);
    });
  });
}
