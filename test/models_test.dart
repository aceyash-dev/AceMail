import 'package:ace_mail/data/limits.dart';
import 'package:ace_mail/models/ace_account.dart';
import 'package:ace_mail/util/file_names.dart';
import 'package:ace_mail/models/mail_folder.dart';
import 'package:ace_mail/models/message_summary.dart';
import 'package:ace_mail/util/dates.dart';
import 'package:ace_mail/widgets/avatar.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MailFolder', () {
    MailFolder from(String name, List<MailboxFlag> flags) =>
        MailFolder.fromMailbox(
          Mailbox(
            encodedName: name,
            encodedPath: name,
            flags: flags,
            pathSeparator: '/',
          ),
        );

    test('recognises roles from the server flags', () {
      expect(from('INBOX', <MailboxFlag>[MailboxFlag.inbox]).role,
          FolderRole.inbox);
      expect(from('Sent', <MailboxFlag>[MailboxFlag.sent]).role,
          FolderRole.sent);
      expect(from('Drafts', <MailboxFlag>[MailboxFlag.drafts]).role,
          FolderRole.drafts);
      expect(from('Trash', <MailboxFlag>[MailboxFlag.trash]).role,
          FolderRole.trash);
    });

    test('falls back to the folder name when the server flags are bare', () {
      expect(from('Sent Items', <MailboxFlag>[]).role, FolderRole.sent);
      expect(from('Junk E-mail', <MailboxFlag>[]).role, FolderRole.junk);
      expect(from('Random', <MailboxFlag>[]).role, FolderRole.folder);
    });

    test('orders the inbox first and everything else after', () {
      final MailFolder inbox = from('INBOX', <MailboxFlag>[MailboxFlag.inbox]);
      final MailFolder other = from('Archive', <MailboxFlag>[]);
      expect(inbox.sortOrder, lessThan(other.sortOrder));
    });
  });

  group('MessageSummary', () {
    test('reads sender, subject and flags off a MIME message', () {
      final MimeMessage message = MimeMessage.parseFromText(
        'From: Priya Sharma <priya@acme.in>\r\n'
        'Subject: Q4 deck\r\n'
        'Date: Mon, 19 Oct 2026 10:00:00 +0530\r\n'
        '\r\n'
        'body\r\n',
      );
      // Flags arrive from the FETCH, not from a header.
      message.flags = <String>[MessageFlags.seen, MessageFlags.flagged];
      final MessageSummary summary = MessageSummary.fromMime(message);

      expect(summary.fromName, 'Priya Sharma');
      expect(summary.fromEmail, 'priya@acme.in');
      expect(summary.subject, 'Q4 deck');
      expect(summary.isSeen, isTrue);
      expect(summary.isFlagged, isTrue);
    });

    test('copyWith only changes what it is given', () {
      const MessageSummary original = MessageSummary(
        uid: 7,
        sequenceId: 7,
        subject: 's',
        fromName: 'n',
        fromEmail: 'e@x.com',
        date: null,
        isSeen: true,
        isFlagged: false,
      );

      expect(original.copyWith(isFlagged: true).isSeen, isTrue);
      expect(original.copyWith(isSeen: false).isSeen, isFalse);
    });

    test('derives two-letter initials', () {
      const MessageSummary summary = MessageSummary(
        uid: 1,
        sequenceId: 1,
        subject: 's',
        fromName: 'Priya Sharma',
        fromEmail: 'p@x.com',
        date: null,
        isSeen: true,
        isFlagged: false,
      );
      expect(summary.initials, 'PS');
    });
  });

  group('MailAvatar', () {
    test('initials come from the name, then the address', () {
      expect(MailAvatar.initialsFor('Priya Sharma', 'p@x.com'), 'PS');
      expect(MailAvatar.initialsFor('', 'priya@x.com'), 'PR');
      expect(MailAvatar.initialsFor('', ''), '?');
    });

    test('the Gravatar URL is the documented md5 form', () {
      // md5('MyEmailAddress@example.com') is the example in Gravatar's docs.
      expect(
        MailAvatar.gravatarUrl('MyEmailAddress@example.com', size: 80),
        'https://www.gravatar.com/avatar/'
        '0bc83cb571cd1c50ba6f3e8a78ef1346?d=404&s=80',
      );
    });

    test('the address is lowercased and trimmed before hashing', () {
      expect(
        MailAvatar.gravatarUrl('  MyEmailAddress@example.com  '),
        MailAvatar.gravatarUrl('myemailaddress@example.com'),
      );
    });
  });

  group('AceAccount', () {
    test('round-trips through JSON', () {
      const AceAccount account = AceAccount(
        email: 'a@example.com',
        imapHost: 'imap.example.com',
        imapPort: 993,
        smtpHost: 'smtp.example.com',
        smtpPort: 587,
      );

      final AceAccount restored =
          AceAccount.fromJson(account.toJson());

      expect(restored.email, account.email);
      expect(restored.imapHost, account.imapHost);
      expect(restored.smtpPort, account.smtpPort);
    });
  });

  group('attachment file names', () {
    test('a path-like name cannot escape the chosen folder', () {
      for (final String raw in <String>[
        '../../etc/passwd',
        r'C:\Windows\evil.exe',
        '/absolute/path',
      ]) {
        final String safe = sanitizeFileName(raw);
        expect(safe, isNot(contains('/')), reason: raw);
        expect(safe, isNot(contains(r'\')), reason: raw);
        expect(safe.startsWith('.'), isFalse, reason: raw);
      }
    });

    test('control characters are stripped', () {
      expect(sanitizeFileName('in\u0000voice.pdf'), 'invoice.pdf');
    });

    test('an over-long name is capped', () {
      final String safe = sanitizeFileName('a' * 500);
      expect(safe.length, MailLimits.maxFileNameLength);
    });

    test('an empty or unusable name falls back', () {
      expect(sanitizeFileName(''), 'attachment');
      expect(sanitizeFileName('   '), 'attachment');
      expect(sanitizeFileName('...'), 'attachment');
    });

    test('an ordinary name is left alone', () {
      expect(sanitizeFileName('Q4 report (final).pdf'), 'Q4 report (final).pdf');
    });
  });

  group('dates', () {
    test('formats a same-day timestamp as a time', () {
      final DateTime now = DateTime.now();
      expect(formatListDate(now), matches(RegExp(r'^\d{2}:\d{2}$')));
    });

    test('formats an older date with a month name', () {
      expect(
        formatListDate(DateTime(2026, 1, 5, 9)),
        contains('Jan'),
      );
    });

    test('an absent date formats as empty', () {
      expect(formatListDate(null), '');
    });
  });
}
