import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Looks up a sender's BIMI logo.
///
/// BIMI (Brand Indicators for Message Identification) lets a domain publish its
/// own logo as a DNS TXT record at `default._bimi.<domain>`. `dart:io` has no
/// TXT resolver, so this asks a DNS-over-HTTPS endpoint instead — which has the
/// side benefit that the lookup is an ordinary HTTPS request a network can
/// simply refuse, rather than something that silently half-works.
///
/// The record points at an SVG; fetching and drawing it is the caller's job.
abstract final class BimiResolver {
  static const Duration _timeout = Duration(seconds: 6);
  static const int _cacheLimit = 400;
  static const String _endpoint = 'https://dns.google/resolve';

  /// domain -> logo URL, or null when the domain publishes no usable record.
  static final Map<String, String?> _cache = <String, String?>{};

  static Future<String?> logoFor(String email) async {
    final int at = email.lastIndexOf('@');
    if (at <= 0 || at == email.length - 1) return null;

    final String domain = email.substring(at + 1).trim().toLowerCase();
    if (domain.isEmpty || domain.contains(' ')) return null;

    if (_cache.containsKey(domain)) return _cache[domain];

    String? logo;
    try {
      logo = await _lookup(domain);
    } catch (_) {
      // No DNS, no record, or a refusal: all mean "no logo".
      logo = null;
    }

    if (_cache.length > _cacheLimit) _cache.clear();
    _cache[domain] = logo;
    return logo;
  }

  static Future<String?> _lookup(String domain) async {
    final Uri uri =
        Uri.parse('$_endpoint?name=default._bimi.$domain&type=TXT');
    final HttpClient client = HttpClient()..connectionTimeout = _timeout;

    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/dns-json');
      final HttpClientResponse response =
          await request.close().timeout(_timeout);
      if (response.statusCode != 200) return null;
      final String body = await response.transform(utf8.decoder).join();
      return parseRecord(body);
    } finally {
      client.close(force: true);
    }
  }

  /// Pulls the `l=` logo URL out of a DNS-over-HTTPS answer. Pure, so it can be
  /// tested against a captured response.
  static String? parseRecord(String json) {
    final Object? decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) return null;

    final List<dynamic> answers =
        decoded['Answer'] as List<dynamic>? ?? <dynamic>[];
    for (final dynamic answer in answers) {
      if (answer is! Map<String, dynamic>) continue;
      final String text = (answer['data'] as String? ?? '').replaceAll('"', '');
      final String? logo = logoFromRecord(text);
      if (logo != null) return logo;
    }
    return null;
  }

  /// `v=BIMI1; l=https://example.com/logo.svg; a=https://example.com/vmc.pem`
  static String? logoFromRecord(String record) {
    for (final String part in record.split(';')) {
      final String trimmed = part.trim();
      if (trimmed.length < 2 || !trimmed.toLowerCase().startsWith('l=')) {
        continue;
      }

      final Uri? uri = Uri.tryParse(trimmed.substring(2).trim());
      // https and a real host only: a logo is remote content, and the record is
      // attacker-controlled.
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) continue;
      return uri.toString();
    }
    return null;
  }
}
