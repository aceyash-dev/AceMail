import 'package:enough_mail/enough_mail.dart';

/// A folder in the mailbox, with its role resolved once so the UI never has to
/// re-derive it. Roles drive ordering and the friendly label.
enum FolderRole { unified, inbox, sent, drafts, trash, junk, archive, folder }

/// Every account's inbox, as one list.
///
/// Not a folder on any server: it has no path and nothing is ever selected from
/// it. It exists so the rail has something to point at when somebody is looking
/// at all their mail at once, which is the view a person with two addresses
/// wants most of the time.
const MailFolder kUnifiedInbox = MailFolder(
  name: 'All inboxes',
  path: '',
  role: FolderRole.unified,
  unseen: 0,
);

class MailFolder {
  const MailFolder({
    required this.name,
    required this.path,
    required this.role,
    required this.unseen,
    this.total = 0,
    this.uidValidity,
  });

  final String name;
  final String path;
  final FolderRole role;
  final int unseen;

  /// How many messages the folder holds, as the server last said.
  ///
  /// The rail shows this rather than the unread count: "how much mail is in
  /// here" is the question a list of folders answers, and unread is already
  /// said by the rows themselves. Zero means the server did not say, which is
  /// shown as nothing rather than as "0".
  final int total;

  /// The same folder with a different unread count.
  ///
  /// The count is the one thing about a folder that changes while it is on
  /// screen: reading a message makes it one less. [MailFolder] is immutable, so
  /// the session replaces the entry rather than mutating it.
  MailFolder copyWith({int? unseen, int? total}) => MailFolder(
        name: name,
        path: path,
        role: role,
        unseen: unseen ?? this.unseen,
        total: total ?? this.total,
        uidValidity: uidValidity,
      );

  /// The server's UIDVALIDITY for this mailbox, when it told us.
  ///
  /// UIDs are only meaningful within one generation of a mailbox: if the server
  /// renumbers it — a restore, a migration, a rebuild — the same number is a
  /// different message. Null means the server did not say, which is treated as
  /// "cannot tell" rather than as a change.
  final int? uidValidity;

  factory MailFolder.fromMailbox(Mailbox mailbox) => MailFolder(
        name: _cleanName(mailbox.name),
        path: mailbox.path,
        role: _roleOf(mailbox),
        unseen: mailbox.messagesUnseen,
        total: mailbox.messagesExists ?? 0,
        uidValidity: mailbox.uidValidity,
      );

  /// The server's name, without the container it may be nested in.
  ///
  /// Gmail reports its system folders as `[Gmail]/All Mail` and `[Gmail]/Sent
  /// Mail`. Most servers hand over the decoded leaf — enough_mail does — but not
  /// all do, and a rail that reads "[Gmail]/All Mail" is a rail with a bug in
  /// it. The bracket is the container, not the folder.
  static String _cleanName(String name) {
    final RegExp nested = RegExp(r'^\[[^\]]+\]/\s*');
    return name.replaceFirst(nested, '').trim();
  }

  static FolderRole _roleOf(Mailbox mailbox) {
    if (mailbox.isInbox) return FolderRole.inbox;

    // The server's own flags first. RFC 6154 exists for exactly this: a mailbox
    // says `\Trash` whatever it is called, and guessing from the name misses a
    // folder called "Papierkorb" or "Bin" or "Wastebasket". Missing the trash is
    // not a cosmetic problem — the app refuses to delete anything at all when it
    // cannot find one, because the alternative is guessing where to put mail.
    if (mailbox.isSent) return FolderRole.sent;
    if (mailbox.isDrafts) return FolderRole.drafts;
    if (mailbox.isTrash) return FolderRole.trash;
    if (mailbox.isJunk) return FolderRole.junk;
    if (mailbox.isArchive) return FolderRole.archive;

    // Names only when the server said nothing, which is what older ones do.
    final String n = mailbox.name.toLowerCase();
    if (n.contains('sent')) return FolderRole.sent;
    if (n.contains('draft')) return FolderRole.drafts;
    if (n.contains('trash') || n.contains('deleted')) return FolderRole.trash;
    // `bulk` is Yahoo's, and it is the same folder under a different word: a
    // junk folder that shows up as a plain one is a folder nobody knows to
    // check.
    if (n.contains('junk') || n.contains('spam') || n.contains('bulk')) {
      return FolderRole.junk;
    }
    if (n.contains('archive') || n.contains('all mail')) {
      return FolderRole.archive;
    }
    return FolderRole.folder;
  }

  String get label => switch (role) {
        FolderRole.unified => 'All inboxes',
        FolderRole.inbox => 'Inbox',
        FolderRole.sent => 'Sent',
        FolderRole.drafts => 'Drafts',
        FolderRole.trash => 'Trash',
        FolderRole.junk => 'Spam',
        FolderRole.archive => 'Archive',
        FolderRole.folder => name,
      };

  int get sortOrder => switch (role) {
        FolderRole.unified => -1,
        FolderRole.inbox => 0,
        FolderRole.sent => 1,
        FolderRole.drafts => 2,
        FolderRole.archive => 3,
        FolderRole.junk => 4,
        FolderRole.trash => 5,
        FolderRole.folder => 6,
      };

  @override
  bool operator ==(Object other) => other is MailFolder && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// Whether a cached page and a mailbox are from the same generation.
///
/// UIDs are only meaningful within one generation: if the server renumbers a
/// mailbox, the same number is a different message, and a cached row's uid now
/// points somewhere else entirely.
///
/// Deliberately **fail-open**. A page is dropped only when both sides say
/// something and they disagree. A server that does not report UIDVALIDITY is
/// not evidence of a change, and treating "cannot tell" as "changed" would
/// throw away a good cache on every folder open — losing the thing the cache
/// exists for, to guard against something that has not happened.
bool sameMailboxGeneration(int? cachedUnder, int? current) {
  if (cachedUnder == null || current == null) return true;
  return cachedUnder == current;
}
