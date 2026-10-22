import '../services/mail_errors.dart';

/// The order of a removal: refuse, then copy, then flag and expunge.
///
/// Written as a function that takes its steps, so the **order** is a property a
/// test can assert without a mail server. The bug this replaces was exactly an
/// ordering bug: the safety check ran *after* the copy, so a refused move had
/// already put a copy in the target folder — the user was told nothing had
/// happened, and was left with a duplicate.
///
/// [copy] is the step that must not run when the removal is refused. For a
/// permanent delete there is nothing to copy, and the caller passes a no-op.
Future<void> removeMessage({
  required bool canRemoveSafely,
  required String refusal,
  required Future<void> Function() copy,
  required Future<void> Function() flagAndExpunge,
}) async {
  if (!canRemoveSafely) throw MailRejectedException(refusal);
  await copy();
  await flagAndExpunge();
}
