import 'dart:convert';
import 'dart:io';

/// A release that exists, as the app needs to describe it.
class UpdateRelease {
  const UpdateRelease({
    required this.version,
    required this.name,
    required this.notes,
    required this.url,
    this.published,
  });

  /// `0.6.0+82`, from the tag. The tag may or may not carry a leading `v`.
  final String version;

  /// The release's title, which is often just the version again.
  final String name;

  /// The release notes — the changelog section for that build, as markdown.
  final String notes;

  /// The page a person goes to for the download.
  final String url;

  final DateTime? published;

  bool get hasNotes => notes.trim().isNotEmpty;
}

/// Whether a newer build exists.
///
/// The app has no update mechanism and no store listing it controls, so the one
/// honest thing it can do is look at the releases it publishes and say so. This
/// asks GitHub, once a day at most, and never sends anything about the person
/// using it: no identifier, no account, no version — the request is a plain
/// `GET` for the latest release of a public repository.
///
/// Off is a switch, and off means no request is ever made.
abstract final class UpdateCheck {
  /// The releases endpoint. Public, unauthenticated, and rate-limited per IP
  /// rather than per account, which is why this is asked for once a day.
  static const String _api =
      'https://api.github.com/repos/tab-gl/AceMail/releases/latest';

  static const Duration _timeout = Duration(seconds: 12);

  /// The latest published release, or null when there is nothing to say.
  ///
  /// Silent on every failure — offline, rate-limited, a proxy answering HTML.
  /// An update check that interrupts somebody to tell them it could not check
  /// is worse than one that says nothing.
  static Future<UpdateRelease?> latest() async {
    final HttpClient client = HttpClient()..connectionTimeout = _timeout;
    try {
      final HttpClientRequest request = await client.getUrl(Uri.parse(_api));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'AceMail');
      final HttpClientResponse response =
          await request.close().timeout(_timeout);
      if (response.statusCode != 200) return null;
      final String body =
          await response.transform(utf8.decoder).join().timeout(_timeout);
      return parse(body);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// The release out of a GitHub `/releases/latest` body, or null.
  ///
  /// Pure, so the shape of the answer can be tested against a captured body
  /// rather than against the network.
  static UpdateRelease? parse(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final Object? tag = decoded['tag_name'] ?? decoded['name'];
    if (tag is! String || tag.trim().isEmpty) return null;

    return UpdateRelease(
      version: versionOf(tag),
      name: (decoded['name'] as String?)?.trim().isNotEmpty ?? false
          ? (decoded['name'] as String).trim()
          : versionOf(tag),
      notes: (decoded['body'] as String?) ?? '',
      url: (decoded['html_url'] as String?) ?? 'https://github.com/tab-gl/AceMail/releases',
      published: DateTime.tryParse(decoded['published_at'] as String? ?? ''),
    );
  }

  /// `v0.6.0+82` → `0.6.0+82`. Tags are written both ways.
  static String versionOf(String tag) {
    final String trimmed = tag.trim();
    return trimmed.startsWith('v') || trimmed.startsWith('V')
        ? trimmed.substring(1)
        : trimmed;
  }

  /// Whether [candidate] is a newer build than [current].
  ///
  /// Compared piece by piece: the version name first (0.6.0 → 0.7.0 is newer),
  /// then the build number after the `+`, because 0.6.0+83 is a newer install
  /// than 0.6.0+82 and the name alone cannot tell them apart. A candidate that
  /// cannot be read is not newer — "I could not understand this" must never
  /// turn into "there is an update".
  static bool isNewer(String candidate, String current) {
    final _Version? next = _parts(candidate);
    final _Version? mine = _parts(current);
    if (next == null || mine == null) return false;

    // Name first, padded so 0.6 and 0.6.0 compare equal.
    final int nameLength = next.length > mine.length ? next.length : mine.length;
    for (int i = 0; i < nameLength; i++) {
      final int a = i < mine.length ? mine[i] : 0;
      final int b = i < next.length ? next[i] : 0;
      if (b != a) return b > a;
    }
    return next.build > mine.build;
  }

  static _Version? _parts(String raw) {
    final String text = versionOf(raw).split('-').first.trim();
    if (text.isEmpty) return null;
    final List<String> halves = text.split('+');
    final List<int> name = <int>[];
    for (final String piece in halves.first.split('.')) {
      final int? value = int.tryParse(piece);
      if (value == null) return null;
      name.add(value);
    }
    if (name.isEmpty) return null;
    final int build = halves.length > 1 ? (int.tryParse(halves[1]) ?? 0) : 0;
    return _Version(name, build);
  }
}

/// A version name and its build number.
class _Version {
  const _Version(this.name, this.build);

  final List<int> name;
  final int build;

  int get length => name.length;

  int operator [](int index) => name[index];
}
