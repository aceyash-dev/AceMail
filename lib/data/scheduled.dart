import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A message waiting for its moment.
class ScheduledSend {
  const ScheduledSend({
    required this.id,
    required this.account,
    required this.at,
    required this.to,
    this.cc = '',
    this.subject = '',
    this.body = '',
  });

  /// When it was queued. Unique enough to name it by, and stable across a
  /// restart — a counter would collide with itself the moment the file is read
  /// back.
  final String id;

  /// Which account sends it. A scheduled message outlives the screen that wrote
  /// it, and the screen is not the thing that knows how to send.
  final String account;

  final DateTime at;
  final String to;
  final String cc;
  final String subject;
  final String body;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'account': account,
        'at': at.toIso8601String(),
        'to': to,
        'cc': cc,
        'subject': subject,
        'body': body,
      };

  static ScheduledSend? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Object? id = raw['id'];
    final Object? account = raw['account'];
    final Object? at = DateTime.tryParse(raw['at'] as String? ?? '');
    final Object? to = raw['to'];
    if (id is! String || account is! String || at == null || to is! String) {
      return null;
    }
    return ScheduledSend(
      id: id,
      account: account,
      at: at,
      to: to,
      cc: raw['cc'] as String? ?? '',
      subject: raw['subject'] as String? ?? '',
      body: raw['body'] as String? ?? '',
    );
  }
}

/// Messages queued to go later.
///
/// On disk rather than in memory, because the whole point is that it outlives
/// the app: a message scheduled for tomorrow morning has to survive the phone
/// being closed, restarted and left alone overnight.
abstract final class Scheduled {
  /// How many are kept. A queue nobody can see the end of is a queue that grows
  /// until somebody notices, and fifty is more than anybody schedules.
  static const int limit = 50;

  static final List<ScheduledSend> _pending = <ScheduledSend>[];
  static bool _loaded = false;
  static File? _file;

  static List<ScheduledSend> get all {
    final List<ScheduledSend> copy = List<ScheduledSend>.of(_pending)
      ..sort((ScheduledSend a, ScheduledSend b) => a.at.compareTo(b.at));
    return copy;
  }

  /// The ones whose moment has come, oldest first.
  static List<ScheduledSend> due(DateTime now) => all
      .where((ScheduledSend m) => !m.at.isAfter(now))
      .toList();

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      await _ensureFile();
      if (!await _file!.exists()) return;
      final Object? decoded = jsonDecode(await _file!.readAsString());
      if (decoded is! List) return;
      _pending
        ..clear()
        ..addAll(
          decoded
              .map(ScheduledSend.fromJson)
              .whereType<ScheduledSend>(),
        );
    } catch (_) {
      // A file that will not read is an empty queue, not a crash. Losing it
      // loses a message somebody meant to send, which is a real loss — but not
      // one worth refusing to start the app over.
    }
  }

  static Future<void> add(ScheduledSend message) async {
    await load();
    _pending.add(message);
    // Oldest first when it is full: what is dropped is what has been waiting
    // longest, which is what somebody has most likely already noticed.
    while (_pending.length > limit) {
      _pending.sort((ScheduledSend a, ScheduledSend b) => a.at.compareTo(b.at));
      _pending.removeAt(0);
    }
    await _persist();
  }

  static Future<void> remove(String id) async {
    await load();
    _pending.removeWhere((ScheduledSend m) => m.id == id);
    await _persist();
  }

  static Future<void> _ensureFile() async {
    if (_file != null) return;
    final Directory directory = await getApplicationSupportDirectory();
    _file = File('${directory.path}/scheduled.json');
  }

  static Future<void> _persist() async {
    try {
      await _ensureFile();
      await _file!.writeAsString(
        jsonEncode(<Object?>[for (final ScheduledSend m in all) m.toJson()]),
        flush: true,
      );
    } catch (_) {
      // Nothing useful to do about it.
    }
  }
}
