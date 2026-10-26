import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../data/account_store.dart';
import '../data/preferences.dart';
import '../data/scheduled.dart';
import 'google_auth.dart';
import '../models/mail_folder.dart';
import '../models/message_summary.dart';
import 'mail_service.dart';
import '../util/redact.dart';
import 'mail_errors.dart';
import 'mail_watcher.dart';
import 'notifications.dart';

/// The task name WorkManager knows this by.
const String kMailCheckTask = 'app.tab.mail.check';

/// The entry point WorkManager calls when it decides it is time.
///
/// This runs in its own isolate, with no widget tree and no provider scope, so
/// it does everything it needs from storage: the accounts and their passwords
/// come from the keychain, the last-seen uid from shared preferences.
@pragma('vm:entry-point')
void mailCheckDispatcher() {
  Workmanager().executeTask((String task, Map<String, dynamic>? input) async {
    if (task != kMailCheckTask) return true;
    await AceNotifications.initialise();

    // WorkManager retries a task that reports failure, on its own schedule.
    // That is what a dropped connection deserves. It is *not* what a wrong
    // password deserves: that would be retried forever and never succeed, so
    // only a connection failure is passed up as one.
    bool worthRetrying = false;
    await checkAllAccounts(
      onTransientFailure: () => worthRetrying = true,
    );
    // The same job from the person's point of view: something the app was going
    // to do while they were not looking.
    await sendDue(onTransientFailure: () => worthRetrying = true);
    return !worthRetrying;
  });
}

/// Checks every stored account once, and notifies for anything new.
///
/// Returns the accounts that had news, which is what the tests assert on and
/// what a foreground caller can show.
///
/// [onTransientFailure] is called once for each account whose check failed in a
/// way worth trying again — a connection that dropped, a server that did not
/// answer. A rejected password is not one of those and is not reported here.
/// Without it the caller cannot tell "nothing new" from "could not ask", which
/// is how a worker reports success while discovering no mail at all.
Future<List<String>> checkAllAccounts({void Function()? onTransientFailure}) async {
  final List<String> withNews = <String>[];

  // Its own handle, because this is where the outcome of each account is
  // recorded and [checkOne] keeps its own.
  final Preferences status = Preferences();
  await status.load();

  final AccountLoad loaded;
  try {
    loaded = await AccountStore().loadAll();
  } catch (error) {
    // A keychain that will not open yet is temporary, and worth another run.
    onTransientFailure?.call();
    debugPrint('Ace Mail: could not read accounts (${Redact.safe(error)})');
    return withNews;
  }

  for (final StoredAccount stored in loaded.accounts) {
    try {
      final bool has = await checkOne(stored);
      if (has) withNews.add(stored.account.email);
      await status.recordCheck(stored.account.email, category: 'ok');
    } catch (error) {
      // One account failing must not stop the others, and must not crash a
      // background isolate where nobody would see it.
      final MailException classified =
          MailErrors.classify(error, fallback: '');
      if (classified is MailConnectionException) {
        onTransientFailure?.call();
      }
      // A category, never the message. A server's text can quote the command
      // that failed, and the command can carry a password.
      await status.recordCheck(
        stored.account.email,
        category: switch (classified) {
          MailAuthException() => 'auth',
          MailConnectionException() => 'connection',
          _ => 'server',
        },
      );
      debugPrint(
        'Ace Mail: check failed for ${Redact.address(stored.account.email)} '
        '(${Redact.safe(error)})',
      );
    }
  }
  return withNews;
}

/// Checks one account. Returns true when it found something new.
Future<bool> checkOne(StoredAccount stored) async {
  // A Google account has no stored password: it is reached with a token, and
  // one that expires in about an hour. This used to hand `stored.password` —
  // an empty string — to a Gmail account, so the check failed for every Gmail
  // user and they never got a new-mail notification at all.
  final MailService service = MailService(
    stored.account,
    tokenProvider: stored.account.isGoogle ? () => GoogleAuth.token(stored.account.email) : null,
  );
  final Preferences prefs = Preferences();
  await prefs.load();

  try {
    final String? secret = stored.account.isGoogle
        ? await GoogleAuth.token(stored.account.email)
        : stored.password;
    if (secret == null) return false;

    final List<MailFolder> folders = await service.connect(secret);
    final MailFolder inbox = folders.firstWhere(
      (MailFolder f) => f.role == FolderRole.inbox,
      orElse: () => folders.first,
    );

    final List<int> uids = await service.listMessageUids(inbox);

    // A UID is only meaningful inside one mailbox namespace. A provider that
    // recreates a mailbox starts numbering again from one, and a marker saved
    // from the old namespace then sits above every new message — so nothing
    // ever looks new again, silently, until the numbers climb back past it.
    //
    // When the namespace has changed the marker is moved to the top of the new
    // one and this check announces nothing. Announcing everything would be
    // five thousand notifications for a mailbox that already existed, which is
    // not a notification, it is an alarm.
    final int validity = inbox.uidValidity ?? 0;
    final int storedValidity = prefs.lastSeenUidValidity(stored.account.email);
    if (validity != 0 && storedValidity != 0 && validity != storedValidity) {
      await prefs.setLastSeenUid(
        stored.account.email,
        uids.isEmpty ? 0 : uids.reduce((int a, int b) => a > b ? a : b),
        validity: validity,
      );
      return false;
    }

    final int highestSeen = prefs.lastSeenUid(stored.account.email);
    final List<int> previous = highestSeen == 0 ? <int>[] : <int>[highestSeen];

    // The newest messages are first in the list, so the subject to show is the
    // one at the front.
    String? subject;
    if (uids.isNotEmpty) {
      final List<MessageSummary> newest = await service.fetchSummariesByUid(
        inbox,
        <int>[uids.first],
      );
      if (newest.isNotEmpty) subject = newest.first.subject;
    }

    final WatchResult result = MailWatcher.compare(
      previousUids: previous,
      currentUids: uids,
      newestSubject: subject,
    );

    if (uids.isNotEmpty) {
      final int highest = uids.reduce((int a, int b) => a > b ? a : b);
      // Saved with the namespace it was read in, so the next check can tell
      // whether it is still talking about the same mailbox.
      await prefs.setLastSeenUid(
        stored.account.email,
        highest,
        validity: validity,
      );
    }

    // Silent overnight, but the mail is still fetched and still counted — the
    // notification is what waits, not the work. Opening the app in the morning
    // finds everything already there.
    if (result.hasNews && !prefs.isQuietAt(DateTime.now())) {
      await AceNotifications.newMail(
        account: stored.account.email,
        count: result.count,
        subject: result.newestSubject,
        privatePreviews: prefs.privatePreviews,
      );
    }
    return result.hasNews;
  } finally {
    await service.disconnect();
  }
}

/// Sends anything whose moment has come.
///
/// Runs in the same worker as the mail check. A message that is due is sent and
/// removed from the queue; one that fails is left where it is, so the next run
/// tries again rather than losing it. Only a connection failure is worth
/// retrying — a rejected password would be retried forever and never succeed.
Future<void> sendDue({void Function()? onTransientFailure}) async {
  await Scheduled.load();
  final List<ScheduledSend> due = Scheduled.due(DateTime.now());
  if (due.isEmpty) return;

  final AccountLoad loaded;
  try {
    loaded = await AccountStore().loadAll();
  } catch (error) {
    onTransientFailure?.call();
    debugPrint('Ace Mail: could not read accounts (${Redact.safe(error)})');
    return;
  }

  for (final ScheduledSend message in due) {
    // A loop rather than a collection extension: the app has no dependency for
    // one, and a lookup that is written out cannot be the wrong helper.
    StoredAccount? stored;
    for (final StoredAccount candidate in loaded.accounts) {
      if (candidate.account.email == message.account) {
        stored = candidate;
        break;
      }
    }
    if (stored == null) {
      // The account is gone. A message that can never be sent is not a queue,
      // it is a stuck entry that shows up in a list forever.
      await Scheduled.remove(message.id);
      continue;
    }

    final MailService service = MailService(
      stored.account,
      tokenProvider: stored.account.isGoogle
          ? () => GoogleAuth.token(stored!.account.email)
          : null,
    );
    try {
      final String? secret = stored.account.isGoogle
          ? await GoogleAuth.token(stored.account.email)
          : stored.password;
      if (secret == null) {
        // No token without asking somebody, so it waits for a run that can.
        continue;
      }
      await service.connect(secret);
      await service.send(
        to: message.to,
        cc: message.cc,
        subject: message.subject,
        body: message.body,
        password: secret,
      );
      await Scheduled.remove(message.id);
    } catch (error) {
      debugPrint('Ace Mail: scheduled send failed (${Redact.safe(error)})');
    } finally {
      unawaited(service.disconnect());
    }
  }
}
