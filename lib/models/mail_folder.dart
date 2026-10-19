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
  });

  final String name;
  final String path;
  final FolderRole role;
  final int unseen;

  factory MailFolder.fromMailbox(Mailbox mailbox) => MailFolder(
        name: mailbox.name,
        path: mailbox.path,
        role: _roleOf(mailbox),
        unseen: mailbox.messagesUnseen,
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
