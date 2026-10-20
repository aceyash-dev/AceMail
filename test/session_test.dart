import 'package:ace_mail/data/account_store.dart';
import 'package:ace_mail/models/mail_folder.dart';
import 'package:ace_mail/models/message_summary.dart';
import 'package:ace_mail/state/mail_controller.dart';
import 'package:ace_mail/state/mail_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

/// An account store that never touches the platform keychain.
class FakeStore extends AccountStore {
  FakeStore([List<StoredAccount> initial = const <StoredAccount>[]])
      : _accounts = List<StoredAccount>.of(initial);

  List<StoredAccount> _accounts;
  String? activeEmail;
  int saves = 0;
  int clears = 0;

  @override
  Future<List<StoredAccount>> loadAll() async => List<StoredAccount>.of(_accounts);

  @override
  Future<void> saveAll(List<StoredAccount> accounts) async {
    _accounts = List<StoredAccount>.of(accounts);
    saves++;
  }

  @override
  Future<String?> loadActiveEmail() async => activeEmail;

  @override
  Future<void> saveActiveEmail(String? email) async => activeEmail = email;

  @override
  Future<void> clear() async {
    _accounts = <StoredAccount>[];
    activeEmail = null;
    clears++;
  }
}

List<int> uidRange(int count) =>
    List<int>.generate(count, (int i) => i + 1);

void main() {
  group('MailSession', () {
    test('connects once, even when called concurrently', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(3));
      final MailSession session = MailSession(
        account: accountA,
        password: 'p',
        transport: transport,
      );

      await Future.wait(<Future<bool>>[session.connect(), session.connect()]);

      expect(transport.connects, 1);
      expect(session.isReady, isTrue);
    });

    test('opens the inbox and loads the first page', () async {
      final FakeTransport transport = FakeTransport()
        ..uids.addAll(uidRange(100));
      final MailSession session = MailSession(
        account: accountA,
        password: 'p',
        transport: transport,
      );

      expect(await session.connect(), isTrue);
      expect(session.selectedFolder?.role, FolderRole.inbox);
      expect(session.messages.length, MailSession.pageSize);
      expect(session.hasMore, isTrue);
    });

    test('loadMore appends older messages and then stops', () async {
      final FakeTransport transport = FakeTransport()
        ..uids.addAll(uidRange(50));
      final MailSession session = MailSession(
        account: accountA,
        password: 'p',
        transport: transport,
      );
      await session.connect();

      await session.loadMore();
      expect(session.messages.length, 50);
      expect(session.hasMore, isFalse);

      final int fetches = transport.pageFetches;
      await session.loadMore();
      expect(transport.pageFetches, fetches, reason: 'no page beyond the end');
    });

    test('a failed connect reports the error and can be retried', () async {
      final MailSession session = MailSession(
        account: accountA,
        password: 'p',
        transport: FakeTransport(failConnect: true),
      );

      expect(await session.connect(), isFalse);
      expect(session.errorMessage, isNotNull);
      expect(session.isReady, isFalse);
    });

    test('search narrows the list and clearing restores the folder', () async {
      final FakeTransport transport = FakeTransport()
        ..uids.addAll(uidRange(60));
      final MailSession session = MailSession(
        account: accountA,
        password: 'p',
        transport: transport,
      );
      await session.connect();

      await session.search('Subject 7');
      expect(session.searchQuery, 'Subject 7');
      expect(transport.lastSearch, 'Subject 7');
      expect(session.messages.map((MessageSummary m) => m.uid), contains(7));

      session.clearSearch();
      await Future<void>.delayed(Duration.zero);
      expect(session.searchQuery, isNull);
    });

    test('opening a message marks it seen', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(3));
      final MailSession session = MailSession(
        account: accountA,
        password: 'p',
        transport: transport,
      );
      await session.connect();

      await session.open(session.messages.first);
      expect(session.openMessage, isNotNull);
      expect(session.messages.first.isSeen, isTrue);
    });

    test('markOpenUnread flips the row back', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(3));
      final MailSession session = MailSession(
        account: accountA,
        password: 'p',
        transport: transport,
      );
      await session.connect();
      await session.open(session.messages.first);
      expect(session.messages.first.isSeen, isTrue);

      await session.markOpenUnread();
      expect(session.messages.first.isSeen, isFalse);
      expect(transport.unread, contains(session.messages.first.uid));
    });

    test('toggleOpenFlagged flips the flag both ways', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(3));
      final MailSession session = MailSession(
        account: accountA,
        password: 'p',
        transport: transport,
      );
      await session.connect();
      await session.open(session.messages.first);
      expect(session.openSummary?.isFlagged, isFalse);

      await session.toggleOpenFlagged();
      expect(session.openSummary?.isFlagged, isTrue);
      expect(transport.flagged, contains(session.messages.first.uid));

      await session.toggleOpenFlagged();
      expect(session.openSummary?.isFlagged, isFalse);
    });

    test('deleteOpenMessage drops it from the list and the paging cursor',
        () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(5));
      final MailSession session = MailSession(
        account: accountA,
        password: 'p',
        transport: transport,
      );
      await session.connect();
      final int uid = session.messages.first.uid;

      await session.open(session.messages.first);
      await session.deleteOpenMessage();

      expect(session.messages.any((MessageSummary m) => m.uid == uid), isFalse);
      expect(session.hasMore, isFalse, reason: 'cursor shrank with the list');
      expect(session.openMessage, isNull);
    });

    test('dispose disconnects the transport', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(2));
      final MailSession session = MailSession(
        account: accountA,
        password: 'p',
        transport: transport,
      );
      await session.connect();

      session.dispose();
      expect(transport.disconnected, isTrue);
    });
  });

  group('MailController', () {
    test('restore brings up only the active account', () async {
      final FakeStore store = FakeStore(<StoredAccount>[
        (account: accountA, password: 'p'),
        (account: accountB, password: 'p'),
      ]);
      final List<FakeTransport> transports = <FakeTransport>[];
      final MailController controller = MailController(
        store: store,
        transportFactory: (_, __) {
          final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(2));
          transports.add(transport);
          return transport;
        },
      );

      await controller.restore();

      expect(controller.accountCount, 2);
      expect(controller.isSignedIn, isTrue);
      expect(
        transports.where((FakeTransport t) => t.connects > 0).length,
        1,
        reason: 'the other account connects lazily, on first switch',
      );
    });

    test('signIn adds an account, makes it active and persists it', () async {
      final FakeStore store = FakeStore();
      final MailController controller = MailController(
        store: store,
        transportFactory: (_, __) => FakeTransport()..uids.addAll(uidRange(2)),
      );

      expect(await controller.signIn(accountA, 'p'), isTrue);
      expect(controller.accountCount, 1);
      expect(controller.account?.email, accountA.email);
      expect(controller.lastEmail, accountA.email);
      expect(store.saves, 1);
      expect(store.activeEmail, accountA.email);
    });

    test('a failed signIn adds nothing and reports the error', () async {
      final FakeStore store = FakeStore();
      final MailController controller = MailController(
        store: store,
        transportFactory: (_, __) => FakeTransport(failConnect: true),
      );

      expect(await controller.signIn(accountB, 'p'), isFalse);
      expect(controller.accountCount, 0);
      expect(controller.isSignedIn, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(store.saves, 0, reason: 'nothing is written on a failed sign-in');
    });

    test('switchTo changes the active account and persists the choice',
        () async {
      final FakeStore store = FakeStore();
      final MailController controller = MailController(
        store: store,
        transportFactory: (_, __) => FakeTransport()..uids.addAll(uidRange(2)),
      );
      await controller.signIn(accountA, 'p');
      await controller.signIn(accountB, 'p');
      expect(controller.activeIndex, 1);

      controller.switchTo(0);

      expect(controller.account?.email, accountA.email);
      expect(controller.lastEmail, accountA.email);
      expect(store.activeEmail, accountA.email);
    });

    test('re-adding an address replaces the existing session', () async {
      final FakeStore store = FakeStore();
      final MailController controller = MailController(
        store: store,
        transportFactory: (_, __) => FakeTransport()..uids.addAll(uidRange(2)),
      );
      await controller.signIn(accountA, 'p');
      await controller.signIn(accountA, 'p2');

      expect(controller.accountCount, 1);
      expect(controller.account?.email, accountA.email);
    });

    test('removeAccount drops it; removing the last signs out', () async {
      final FakeStore store = FakeStore();
      final MailController controller = MailController(
        store: store,
        transportFactory: (_, __) => FakeTransport()..uids.addAll(uidRange(2)),
      );
      await controller.signIn(accountA, 'p');
      await controller.signIn(accountB, 'p');

      await controller.removeAccount(1);
      expect(controller.accountCount, 1);
      expect(controller.account?.email, accountA.email);

      await controller.removeAccount(0);
      expect(controller.accountCount, 0);
      expect(controller.isSignedIn, isFalse);
      expect(store.clears, 1);
    });

    test('the proxy getters follow the active account', () async {
      final FakeStore store = FakeStore();
      final MailController controller = MailController(
        store: store,
        transportFactory: (_, __) => FakeTransport()..uids.addAll(uidRange(45)),
      );
      await controller.signIn(accountA, 'p');

      expect(controller.folders, isNotEmpty);
      expect(controller.messages.length, MailSession.pageSize);
      expect(controller.hasMore, isTrue);
      expect(controller.searchQuery, isNull);

      await controller.search('Subject 3');
      expect(controller.searchQuery, 'Subject 3');
      expect(controller.hasMore, isFalse, reason: 'no paging while searching');
    });

    test('dispose disposes every session', () async {
      final FakeStore store = FakeStore();
      final List<FakeTransport> transports = <FakeTransport>[];
      final MailController controller = MailController(
        store: store,
        transportFactory: (_, __) {
          final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(2));
          transports.add(transport);
          return transport;
        },
      );
      await controller.signIn(accountA, 'p');
      await controller.signIn(accountB, 'p');

      controller.dispose();

      expect(transports.every((FakeTransport t) => t.disconnected), isTrue);
    });
  });
}
