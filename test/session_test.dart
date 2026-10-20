import 'dart:async';

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

  /// Injected so a test can make the keychain misbehave.
  String? loadError;
  String? saveError;
  String? clearError;

  @override
  Future<AccountLoad> loadAll() async =>
      (accounts: List<StoredAccount>.of(_accounts), error: loadError);

  @override
  Future<String?> saveAll(List<StoredAccount> accounts) async {
    if (saveError != null) return saveError;
    _accounts = List<StoredAccount>.of(accounts);
    saves++;
    return null;
  }

  @override
  Future<String?> loadActiveEmail() async => activeEmail;

  @override
  Future<void> saveActiveEmail(String? email) async => activeEmail = email;

  @override
  Future<String?> clear() async {
    if (clearError != null) return clearError;
    _accounts = <StoredAccount>[];
    activeEmail = null;
    clears++;
    return null;
  }
}

MailSession sessionWith(FakeTransport transport, {dynamic account}) =>
    MailSession(
      account: account ?? accountA,
      password: 'p',
      transport: transport,
    );

void main() {
  group('MailSession', () {
    test('connects once, even when called concurrently', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(3));
      final MailSession session = sessionWith(transport);

      await Future.wait(<Future<bool>>[session.connect(), session.connect()]);

      expect(transport.connects, 1);
      expect(session.isReady, isTrue);
    });

    test('opens the inbox and loads the first page', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(100));
      final MailSession session = sessionWith(transport);

      expect(await session.connect(), isTrue);
      expect(session.selectedFolder?.role, FolderRole.inbox);
      expect(session.messages.length, MailSession.pageSize);
      expect(session.hasMore, isTrue);
    });

    test('loadMore appends older messages and then stops', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(50));
      final MailSession session = sessionWith(transport);
      await session.connect();

      await session.loadMore();
      expect(session.messages.length, 50);
      expect(session.hasMore, isFalse);

      final int fetches = transport.pageFetches;
      await session.loadMore();
      expect(transport.pageFetches, fetches, reason: 'no page beyond the end');
    });

    test('a failed connect reports the error and can be retried', () async {
      final MailSession session =
          sessionWith(FakeTransport(failConnect: true));

      expect(await session.connect(), isFalse);
      expect(session.errorMessage, isNotNull);
      expect(session.isReady, isFalse);
    });

    test('a slow folder listing cannot overwrite a newer selection', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(6));
      final MailSession session = sessionWith(transport);
      await session.connect();

      // Hold the inbox open, then switch to a folder that answers at once.
      final Completer<void> gate = transport.gateFor('INBOX');
      final Future<void> slow = session.openFolder(transport.inbox);
      await session.openFolder(transport.archive);
      expect(session.selectedFolder?.path, 'Archive');

      gate.complete();
      await slow;

      expect(
        session.selectedFolder?.path,
        'Archive',
        reason: 'the stale listing must be discarded, not applied',
      );
      expect(session.loadingMessages, isFalse);
    });

    test('a session disposed mid-connect closes the transport quietly',
        () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(2));
      transport.connectGate = Completer<void>();
      final MailSession session = sessionWith(transport);

      final Future<bool> connecting = session.connect();
      session.dispose();
      transport.connectGate!.complete();

      expect(await connecting, isFalse);
      expect(transport.disconnected, isTrue);
      expect(session.isReady, isFalse);
    });

    test('opening a message marks it seen deliberately', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(3));
      final MailSession session = sessionWith(transport);
      await session.connect();

      await session.open(session.messages.first);
      await Future<void>.delayed(Duration.zero);

      expect(session.openMessage, isNotNull);
      expect(session.messages.first.isSeen, isTrue);
      expect(transport.markedSeen, session.messages.first.uid);
    });

    test('delete moves to Trash and never hard-deletes when Trash exists',
        () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(3));
      final MailSession session = sessionWith(transport);
      await session.connect();
      final int uid = session.messages.first.uid;

      await session.open(session.messages.first);
      await session.deleteOpenMessage();

      expect(session.canDeleteSafely, isTrue);
      expect(transport.deletedPermanently, isFalse);
      expect(session.messages.any((MessageSummary m) => m.uid == uid), isFalse);
      expect(session.errorMessage, isNull);
    });

    test('delete refuses rather than hard-deleting when there is no Trash',
        () async {
      final FakeTransport transport =
          FakeTransport(trash: false)..uids.addAll(uidRange(3));
      final MailSession session = sessionWith(transport);
      await session.connect();
      final int uid = session.messages.first.uid;

      await session.open(session.messages.first);
      await session.deleteOpenMessage();

      expect(session.canDeleteSafely, isFalse);
      expect(session.errorMessage, isNotNull);
      expect(
        session.messages.any((MessageSummary m) => m.uid == uid),
        isTrue,
        reason: 'a failed move must not destroy the message',
      );
    });

    test('an explicit permanent delete is allowed without Trash', () async {
      final FakeTransport transport =
          FakeTransport(trash: false)..uids.addAll(uidRange(3));
      final MailSession session = sessionWith(transport);
      await session.connect();
      final int uid = session.messages.first.uid;

      await session.open(session.messages.first);
      await session.deleteOpenMessage(permanently: true);

      expect(transport.deletedPermanently, isTrue);
      expect(session.messages.any((MessageSummary m) => m.uid == uid), isFalse);
    });

    test('search narrows the list and clearing restores the folder', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(60));
      final MailSession session = sessionWith(transport);
      await session.connect();

      await session.search('Subject 7');
      expect(session.searchQuery, 'Subject 7');
      expect(session.messages.map((MessageSummary m) => m.uid), contains(7));

      session.clearSearch();
      await Future<void>.delayed(Duration.zero);
      expect(session.searchQuery, isNull);
    });

    test('send threads the reply headers through', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(1));
      final MailSession session = sessionWith(transport);
      await session.connect();

      await session.send(
        to: 'x@y.com',
        body: 'hi',
        inReplyTo: '<1@x>',
        references: '<0@x> <1@x>',
      );

      expect(transport.lastInReplyTo, '<1@x>');
      expect(transport.lastReferences, '<0@x> <1@x>');
    });

    test('no duplicate Sent copy for a provider that files its own', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(1));
      final MailSession session = sessionWith(transport, account: gmailAccount);
      await session.connect();

      await session.send(to: 'x@y.com', body: 'hi');

      expect(
        transport.lastSentPath,
        isNull,
        reason: 'Gmail already files the sent copy',
      );
    });

    test('files a Sent copy for a provider that does not', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(1));
      final MailSession session = sessionWith(transport);
      await session.connect();

      await session.send(to: 'x@y.com', body: 'hi');

      expect(transport.lastSentPath, 'Sent');
    });

    test('markOpenUnread flips the row back', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(3));
      final MailSession session = sessionWith(transport);
      await session.connect();
      await session.open(session.messages.first);

      await session.markOpenUnread();
      expect(session.messages.first.isSeen, isFalse);
      expect(transport.unread, contains(session.messages.first.uid));
    });

    test('toggleOpenFlagged flips the flag both ways', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(3));
      final MailSession session = sessionWith(transport);
      await session.connect();
      await session.open(session.messages.first);

      await session.toggleOpenFlagged();
      expect(session.openSummary?.isFlagged, isTrue);

      await session.toggleOpenFlagged();
      expect(session.openSummary?.isFlagged, isFalse);
    });

    test('dispose disconnects the transport', () async {
      final FakeTransport transport = FakeTransport()..uids.addAll(uidRange(2));
      final MailSession session = sessionWith(transport);
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
          final FakeTransport transport =
              FakeTransport()..uids.addAll(uidRange(2));
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

    test('an unreadable keychain is reported, not swallowed', () async {
      final FakeStore store = FakeStore()
        ..loadError = 'keychain unavailable';
      final MailController controller = MailController(store: store);

      await controller.restore();

      expect(controller.errorMessage, 'keychain unavailable');
      expect(controller.isSignedIn, isFalse);
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

    test('a storage failure after signing in is reported', () async {
      final FakeStore store = FakeStore()..saveError = 'keychain write failed';
      final MailController controller = MailController(
        store: store,
        transportFactory: (_, __) => FakeTransport()..uids.addAll(uidRange(2)),
      );

      expect(await controller.signIn(accountA, 'p'), isTrue);
      expect(controller.errorMessage, 'keychain write failed');
      expect(controller.isSignedIn, isTrue, reason: 'the session still works');
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
      expect(store.activeEmail, accountA.email);
    });

    test('re-adding an address replaces the session, case-insensitively',
        () async {
      final FakeStore store = FakeStore();
      final MailController controller = MailController(
        store: store,
        transportFactory: (_, __) => FakeTransport()..uids.addAll(uidRange(2)),
      );
      await controller.signIn(accountA, 'p');
      await controller.signIn(accountA, 'p2');

      expect(controller.accountCount, 1);
    });

    test('concurrent sign-ins do not interleave', () async {
      final FakeStore store = FakeStore();
      final MailController controller = MailController(
        store: store,
        transportFactory: (_, __) => FakeTransport()..uids.addAll(uidRange(2)),
      );

      await Future.wait(<Future<bool>>[
        controller.signIn(accountA, 'p'),
        controller.signIn(accountB, 'p'),
      ]);

      expect(controller.accountCount, 2);
      expect(store.saves, 2);
      expect(controller.activeIndex, 1);
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
      expect(controller.canDeleteSafely, isTrue);

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
          final FakeTransport transport =
              FakeTransport()..uids.addAll(uidRange(2));
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
