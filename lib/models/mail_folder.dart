import 'package:enough_mail/enough_mail.dart';

/// A folder in the mailbox, with its role resolved once so the UI never has to
/// re-derive it. Roles drive ordering and the friendly label.
enum FolderRole { inbox, sent, drafts, trash, junk, archive, folder }

class MailFolder {
  const MailFolder({
    required this.name,
    required this.path,
    required this.role,
    required this.unseen,
    this.uidValidity,
  });

  final String name;
  final String path;
  final FolderRole role;
  final int unseen;

  /// The server's UIDVALIDITY for this mailbox, when it told us.
  ///
  /// UIDs are only meaningful within one generation of a mailbox: if the server
  /// renumbers it — a restore, a migration, a rebuild — the same number is a
  /// different message. Null means the server did not say, which is treated as
  /// "cannot tell" rather than as a change.
  final int? uidValidity;

  factory MailFolder.fromMailbox(Mailbox mailbox) => MailFolder(
        name: mailbox.name,
        path: mailbox.path,
        role: _roleOf(mailbox),
        unseen: mailbox.messagesUnseen,
        uidValidity: mailbox.uidValidity,
      );

  static FolderRole _roleOf(Mailbox mailbox) {
    if (mailbox.isInbox) return FolderRole.inbox;
    final String n = mailbox.name.toLowerCase();
    if (n.contains('sent')) return FolderRole.sent;
    if (n.contains('draft')) return FolderRole.drafts;
    if (n.contains('trash') || n.contains('deleted')) return FolderRole.trash;
    if (n.contains('junk') || n.contains('spam')) return FolderRole.junk;
    if (n.contains('archive') || n.contains('all mail')) {
      return FolderRole.archive;
    }
    return FolderRole.folder;
  }

  String get label => switch (role) {
        FolderRole.inbox => 'Inbox',
        FolderRole.sent => 'Sent',
        FolderRole.drafts => 'Drafts',
        FolderRole.trash => 'Trash',
        FolderRole.junk => 'Spam',
        FolderRole.archive => 'Archive',
        FolderRole.folder => name,
      };

  int get sortOrder => switch (role) {
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
