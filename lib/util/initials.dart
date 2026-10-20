/// Two letters standing in for a sender, used by both the list row and the
/// avatar — one implementation, so they cannot disagree about the same person.
String initialsFor(String name, String email) {
  final String source = name.trim().isEmpty ? email.trim() : name.trim();
  if (source.isEmpty) return '?';

  final List<String> parts =
      source.split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';

  if (parts.length == 1) {
    final String only = parts.first;
    return only.substring(0, only.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
