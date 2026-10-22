/// Returns a user-facing reason when an IMAP server cannot safely expunge one UID.
///
/// Bare EXPUNGE removes every message marked \Deleted in the selected mailbox,
/// not just the UID Ace Mail is handling. Refusing is safer than deleting mail
/// another client or the user has already marked for deletion.
String? uidExpungeUnavailableReason({required bool supportsUidPlus}) {
  if (supportsUidPlus) return null;
  return 'This mail server does not support safe single-message deletion. '
      'To avoid removing other messages marked for deletion, Ace Mail has '
      'left this message unchanged.';
}
