import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../data/account_store.dart';
import '../data/preferences.dart';
import 'google_auth.dart';
import '../models/mail_folder.dart';
import '../models/message_summary.dart';
import 'mail_service.dart';
import '../util/redact.dart';
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
    await checkAllAccounts();
    return true;
  });
}

/// Checks every stored account once, and notifies for anything new.
///
/// Returns the accounts that had news, which is what the tests assert on and
/// what a foreground caller can show.
Future<List<String>> checkAllAccounts() async {
  final List<String> withNews = <String>[];

  final AccountLoad loaded;
  try {
    loaded = await AccountStore().loadAll();
  } catch (error) {
    debugPrint('Ace Mail: could not read accounts (${Redact.safe(error)})');
    return withNews;
  }

  for (final StoredAccount stored in loaded.accounts) {
    try {
      final bool has = await checkOne(stored);
      if (has) withNews.add(stored.account.email);
    } catch (error) {
      // One account failing must not stop the others, and must not crash a
      // background isolate where nobody would see it.
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
    tokenProvider: stored.account.isGoogle ? GoogleAuth.token : null,
  );
  final Preferences prefs = Preferences();
  await prefs.load();

  try {
    final String? secret = stored.account.isGoogle
        ? await GoogleAuth.token()
        : stored.password;
    if (secret == null) return false;

    final List<MailFolder> folders = await service.connect(secret);
    final MailFolder inbox = folders.firstWhere(
      (MailFolder f) => f.role == FolderRole.inbox,
      orElse: () => folders.first,
    );

    final List<int> uids = await service.listMessageUids(inbox);
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
      await prefs.setLastSeenUid(stored.account.email, highest);
    }

    if (result.hasNews) {
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
