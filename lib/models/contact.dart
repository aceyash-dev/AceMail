const Object _unsetContactField = Object();

/// Somebody the app has seen in the mail, or somebody the person saved.
class Contact {
  const Contact({
    required this.email,
    this.name = '',
    this.saved = false,
    this.count = 0,
    this.lastSeen,
  });

  final String email;

  /// The name as it appears in mail. Often empty: plenty of mail arrives with a
  /// bare address, and a made-up name is worse than none.
  final String name;

  /// True when the person saved it, rather than the app having seen it.
  final bool saved;

  /// How many messages have come from or gone to this address.
  final int count;

  final DateTime? lastSeen;

  /// What to show as the heading. The address is the fallback, because it is
  /// the thing that is always true.
  String get label => name.trim().isEmpty ? email : name.trim();

  /// Whether there is a name to show underneath the address.
  bool get hasName => name.trim().isNotEmpty && name.trim() != email;

  Contact copyWith({
    String? name,
    bool? saved,
    int? count,
    Object? lastSeen = _unsetContactField,
  }) =>
      Contact(
        email: email,
        name: name ?? this.name,
        saved: saved ?? this.saved,
        count: count ?? this.count,
        lastSeen: identical(lastSeen, _unsetContactField) ? this.lastSeen : lastSeen as DateTime?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'email': email,
        if (name.isNotEmpty) 'name': name,
        if (saved) 'saved': true,
        if (count > 0) 'count': count,
        if (lastSeen != null) 'lastSeen': lastSeen!.toIso8601String(),
      };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        email: (json['email'] as String? ?? '').trim(),
        name: (json['name'] as String? ?? '').trim(),
        saved: json['saved'] as bool? ?? false,
        count: (json['count'] as num?)?.toInt() ?? 0,
        lastSeen: DateTime.tryParse(json['lastSeen'] as String? ?? ''),
      );
}
