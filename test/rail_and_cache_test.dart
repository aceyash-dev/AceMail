import 'dart:io';
import 'dart:math';

import 'package:ace_mail/data/local_cache.dart';
import 'package:ace_mail/data/local_store.dart';
import 'package:ace_mail/data/mail_providers.dart';
import 'package:ace_mail/data/vault.dart';
import 'package:ace_mail/models/mail_folder.dart';
import 'package:ace_mail/models/message_summary.dart';
import 'package:ace_mail/state/mail_controller.dart';
import 'package:ace_mail/state/mail_session.dart';
import 'package:ace_mail/theme/astryx_theme.dart';
import 'package:ace_mail/widgets/chyme_mark.dart';
import 'package:ace_mail/widgets/provider_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';
import 'vault_test.dart' show MemoryKeys;

/// The rail is the same shape for every account, and a folder the server has not
/// offered yet is still drawn — these are the two promises the rail now makes,
/// and the ones that were broken when one account showed six folders and another
/// showed one.
void main() {
  group('the rail', () {
    test('is the standard six before anything is connected', () {
      final MailSession session =
          MailSession(account: accountA, password: 'p', transport: FakeTransport());

      expect(session.railFolders, hasLength(kStandardFolders.length));
      expect(session.railFolders.every((MailFolder f) => f.placeholder), isTrue);
    });

    test('keeps its shape when the server publishes fewer folders', () async {
      // An account with no Archive folder of its own.
      final FakeTransport transport = FakeTransport(archiveFolder: false)
        ..uids.addAll(uidRange(3));
      final MailSession session =
          MailSession(account: accountA, password: 'p', transport: transport);
      await session.connect();

      final List<MailFolder> rail = session.railFolders;
      expect(rail.map((MailFolder f) => f.role), <FolderRole>[
        FolderRole.inbox,
        FolderRole.sent,
        FolderRole.drafts,
        FolderRole.archive,
        FolderRole.junk,
        FolderRole.trash,
      ]);

      // The server's own folders replace their placeholders...
      expect(rail.firstWhere((MailFolder f) => f.role == FolderRole.inbox).placeholder, isFalse);
      // ...and the one it does not have stays a placeholder.
      final MailFolder archive =
          rail.firstWhere((MailFolder f) => f.role == FolderRole.archive);
      expect(archive.placeholder, isTrue);
    });

    test('the controller falls back to the standard six with no account', () {
      final MailController controller = MailController(store: FakeStore());
      expect(controller.railFolders, kStandardFolders);
    });
  });

  group('caching the list', () {
    late Directory dir;
    late LocalStore store;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('ace_list_test');
      final AceVault vault = AceVault(keys: MemoryKeys(), random: Random(5));
      store = LocalStore(
        cache: LocalCache(directory: dir, vault: vault),
        vault: vault,
      );
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('a page round trips through the store', () async {
      final MessageSummary row = MessageSummary(
        uid: 7,
        sequenceId: 7,
        subject: 'Hello',
        fromName: 'Someone',
        fromEmail: 'someone@example.com',
        date: DateTime(2026, 1, 2, 3, 4),
        isSeen: true,
        isFlagged: false,
      );
      await store.saveList('INBOX', 99, <Map<String, Object?>>[row.toCache()]);

      final ({int? uidValidity, List<Map<String, Object?>> messages})? record =
          await store.loadList('INBOX');
      expect(record, isNotNull);
      expect(record!.uidValidity, 99);
      final MessageSummary back = MessageSummary.fromCache(record.messages.single)!;
      expect(back.uid, 7);
      expect(back.subject, 'Hello');
      expect(back.fromEmail, 'someone@example.com');
      expect(back.date, DateTime(2026, 1, 2, 3, 4));
      expect(back.isSeen, isTrue);
    });

    test('the folder list round trips through the store', () async {
      await store.saveFolders('a@example.com', <Map<String, Object?>>[
        kStandardFolders.first.toCache(),
      ]);

      final List<Map<String, Object?>> back = await store.loadFolders('A@Example.com');
      expect(back, hasLength(1));
      expect(MailFolder.fromCache(back.single)?.path, 'INBOX');
    });

    test('a session opens its mailbox from the store with no connection', () async {
      // What was on screen last time.
      await store.saveFolders('a@example.com', <Map<String, Object?>>[
        const MailFolder(
          name: 'Inbox',
          path: 'INBOX',
          role: FolderRole.inbox,
          unseen: 0,
        ).toCache(),
      ]);
      await store.saveList('INBOX', null, <Map<String, Object?>>[
        MessageSummary(
          uid: 1,
          sequenceId: 1,
          subject: 'From last time',
          fromName: 'Sender',
          fromEmail: 'sender@example.com',
          date: DateTime(2026, 1, 1),
          isSeen: false,
          isFlagged: false,
        ).toCache(),
      ]);

      final MailSession session = MailSession(
        account: accountA,
        password: 'p',
        transport: FakeTransport(failConnect: true),
        store: store,
      );

      // The server is unreachable, so there is nothing to connect to.
      expect(await session.connect(), isFalse);

      // The rail is still the standard six, and the folder is still there.
      expect(session.railFolders, hasLength(kStandardFolders.length));
      expect(session.messages, hasLength(1));
      expect(session.messages.single.subject, 'From last time');
    });
  });

  group('marks', () {
    testWidgets('a provider mark is never handed both a width and a height', (
      WidgetTester tester,
    ) async {
      // Yahoo's logo is a wordmark about 5.5 times wider than it is tall, and
      // the avatar can return it on its own — outside the avatar's own box —
      // once the picture lookup for the address has missed. SvgPicture reads a
      // width and a height together as "keep the height, work the width out from
      // the artwork's aspect ratio", which is what drew the wordmark several
      // times the width of the row it sat in. The square is the box; the
      // SvgPicture inside it takes neither. That is the invariant this guards.
      final MailProvider yahoo = kProviderChoices.firstWhere(
        (MailProvider provider) => provider.label == 'Yahoo',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstryxTheme(Brightness.light),
          home: Scaffold(
            body: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[ProviderMark(provider: yahoo, size: 42)],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final SvgPicture svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        svg.width == null || svg.height == null,
        isTrue,
        reason: 'both together means the width is recomputed from the ratio',
      );
      expect(tester.getSize(find.byType(Row)).width, lessThanOrEqualTo(42.5));
    });

    testWidgets('the Chyme mark draws at an icon\'s optical size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstryxTheme(Brightness.light),
          home: const Scaffold(
            body: Center(child: ChymeMark(size: 20, color: Colors.black)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The artwork is full-bleed, so a nominal 20 would read larger than a
      // 20px icon. It corrects itself, the way AceIconView does.
      expect(
        tester.getSize(find.byType(ChymeMark)).width,
        closeTo(20 * ChymeMark.opticalScale, 0.1),
      );
    });
  });
}
