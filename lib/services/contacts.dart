import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/contact.dart';
import '../util/addresses.dart';
import '../models/full_message.dart';
import '../models/message_summary.dart';

/// The addresses this app has seen, and the ones the person saved.
///
/// Two kinds of contact, deliberately kept apart in the record and together in
/// the list. **Saved** is a decision — somebody the person chose to keep.
/// **Seen** is a fact — an address that has written to them, or that they have
/// written to. A contact book that only holds what you remembered to add is
/// empty, and one that treats every address as equal is noise; showing both,
/// marked, is what a mail client can actually offer.
///
/// Kept in a plain file rather than the vault. Addresses are not secrets — they
/// are on the envelope of every message — and the vault exists for what is
/// inside. It is bounded, because a mail client that keeps every address it has
/// ever seen forever is a mail client that grows without limit.
abstract final class Contacts {
  /// How many are kept. The most recently seen go first when it is full, so
  /// what is dropped is what has not been used in the longest time.
  static const int limit = 600;

  static final Map<String, Contact> _byEmail = <String, Contact>{};
  static bool _loaded = false;
  static File? _file;

  /// Whether anything has been loaded or seen. The screen uses this to tell
  /// "no contacts yet" from "not read yet".
  static bool get isEmpty => _byEmail.isEmpty;

  /// Everyone, saved first, then by how recently they were seen.
  ///
  /// Saved first because a decision outranks a coincidence: somebody you chose
  /// to keep should not be pushed below an address that happened to send you a
  /// receipt this morning.
  static List<Contact> get all {
    final List<Contact> contacts = _byEmail.values.toList()
      ..sort((Contact a, Contact b) {
        if (a.saved != b.saved) return a.saved ? -1 : 1;
        final DateTime? x = a.lastSeen;
        final DateTime? y = b.lastSeen;
        if (x == null && y == null) return a.label.toLowerCase().compareTo(b.label.toLowerCase());
        if (x == null) return 1;
        if (y == null) return -1;
        return y.compareTo(x);
      });
    return contacts;
  }

  /// The ones worth showing for [query]. Empty query means everyone.
  static List<Contact> search(String query) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) return all;
    return all
        .where((Contact c) =>
            c.email.toLowerCase().contains(needle) ||
            c.name.toLowerCase().contains(needle))
        .toList();
  }

  static Contact? byEmail(String email) =>
      _byEmail[email.trim().toLowerCase()];

  static Future<void> _ensureFile() async {
    if (_file != null) return;
    final Directory directory =
        await getApplicationSupportDirectory();
    _file = File('${directory.path}/contacts.json');
  }

  /// Reads what was kept. Safe to call more than once.
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      await _ensureFile();
      final File file = _file!;
      if (!await file.exists()) return;
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return;
      for (final Object? entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        final Contact contact = Contact.fromJson(entry);
        if (contact.email.isEmpty) continue;
        _byEmail[contact.email.toLowerCase()] = contact;
      }
    } catch (_) {
      // An unreadable contact file is not worth an error: the addresses are
      // still in the mail, and the list fills up again as it loads.
    }
  }

  /// A write waiting to happen, so that a folder load is one write and not
  /// forty.
  ///
  /// The addresses arrive a page at a time as folders load, and writing the
  /// whole book on every page is the same file rewritten several times a
  /// second for a file that changes slowly. A decision the person made goes
  /// straight to disk; what the mail told us waits a moment.
  static Timer? _writeSoon;

  static void _schedulePersist() {
    _writeSoon?.cancel();
    _writeSoon = Timer(const Duration(seconds: 2), () {
      _writeSoon = null;
      unawaited(_persist());
    });
  }

  /// Writes anything pending, now.
  static Future<void> flush() async {
    if (_writeSoon == null) return;
    _writeSoon!.cancel();
    _writeSoon = null;
    await _persist();
  }

  static Future<void> _persist() async {
    try {
      await _ensureFile();
      _trim();
      await _file!.writeAsString(
        jsonEncode(<Object>[for (final Contact c in all) c.toJson()]),
        flush: true,
      );
    } catch (_) {
      // Losing the file loses the "saved" marks, which is a real loss but not
      // one worth interrupting anybody over.
    }
  }

  static void _trim() {
    if (_byEmail.length <= limit) return;
    // Saved ones are never dropped; the rest go oldest-first.
    final List<Contact> droppable = _byEmail.values
        .where((Contact c) => !c.saved)
        .toList()
      ..sort((Contact a, Contact b) {
        final DateTime x = a.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime y = b.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
        return x.compareTo(y);
      });
    for (final Contact contact in droppable) {
      if (_byEmail.length <= limit) break;
      _byEmail.remove(contact.email.toLowerCase());
    }
  }

  /// Records who a page of mail is from.
  ///
  /// Called as pages load, so the list grows with use rather than needing a
  /// scan of the whole mailbox. Senders only: a summary does not carry the
  /// recipients, and guessing them from a folder would put the account holder
  /// in their own contact list.
  static void observe(List<MessageSummary> messages) {
    bool changed = false;
    for (final MessageSummary message in messages) {
      changed |= _record(message.fromEmail, message.fromName, message.date);
    }
    if (changed) _schedulePersist();
  }

  /// Records who an opened message was sent to.
  ///
  /// The only place the recipients appear — a list row carries the sender and
  /// nothing else — and they come without names, because the model keeps the
  /// addresses as a plain string. A name arrives later, from mail they send.
  /// Records the people a message was sent to.
  ///
  /// Called when a message goes out, not only when one is opened. Loading the
  /// Sent folder does not do this: every message in it has *you* in the From
  /// line, so a book built from senders learns your own address and none of the
  /// people you actually write to. The addresses you chose at send time are the
  /// only place that information exists.
  static void recordSent(Iterable<String> addresses, {DateTime? when}) {
    bool changed = false;
    for (final String email in addresses) {
      changed |= _record(email, '', when);
    }
    if (changed) _schedulePersist();
  }

  static void observeRecipients(FullMessage message) {
    bool changed = false;
    for (final String email in <String>[
      ...message.toEmails.split(','),
      ...message.ccEmails.split(','),
    ]) {
      changed |= _record(email, '', message.date);
    }
    if (changed) _schedulePersist();
  }

  static bool _record(String email, String name, DateTime? when) {
    final String key = email.trim().toLowerCase();
    if (key.isEmpty || !key.contains('@')) return false;
    // An address at your own domain is usually a machine: a receipt, a
    // notification, a mailing list. Not a person to offer to write to.
    if (isMachineAddress(key)) return false;

    final Contact? existing = _byEmail[key];
    final String cleanName = name.trim();
    if (existing == null) {
      _byEmail[key] = Contact(
        email: key,
        name: cleanName,
        count: 1,
        lastSeen: when,
      );
      return true;
    }

    _byEmail[key] = existing.copyWith(
      // A name is kept once found, and replaced only by another name — never
      // wiped by a message that arrived with a bare address.
      name: cleanName.isEmpty ? existing.name : cleanName,
      count: existing.count + 1,
      lastSeen: when ?? existing.lastSeen,
    );
    return true;
  }


  /// Saves or forgets one. Forgetting an address the app has seen leaves it in
  /// the list as an unsaved contact rather than removing it — it is still in
  /// the mail, and pretending otherwise would be a lie the next page undoes.
  static Future<void> setSaved(String email, bool saved) async {
    // A person's decision is written at once; only what the mail volunteered
    // waits.
    final String key = email.trim().toLowerCase();
    final Contact? existing = _byEmail[key];
    if (existing == null) {
      if (!saved) return;
      _byEmail[key] = Contact(email: key, saved: true);
    } else {
      _byEmail[key] = existing.copyWith(saved: saved);
    }
    await _persist();
  }

  /// Adds an address by hand — from the contact sheet, when somebody types one
  /// the app has never seen.
  static Future<Contact> add({required String email, String name = ''}) async {
    final String key = email.trim().toLowerCase();
    final Contact contact = (_byEmail[key] ?? Contact(email: key))
        .copyWith(name: name.trim(), saved: true);
    _byEmail[key] = contact;
    await _persist();
    return contact;
  }

  /// Drops the addresses the app merely saw, keeping the saved ones.
  static Future<void> forgetSeen() async {
    _byEmail.removeWhere((_, Contact c) => !c.saved);
    await _persist();
  }
}
