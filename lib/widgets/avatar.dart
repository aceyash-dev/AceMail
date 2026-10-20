import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import 'astryx_widgets.dart';

/// A sender's picture.
///
/// Looks the address up on Gravatar and falls back to the initials chip — which
/// is also what you get offline, or for the many people who have no Gravatar.
class MailAvatar extends StatelessWidget {
  const MailAvatar({
    super.key,
    required this.email,
    required this.name,
    this.size = 40,
  });

  final String email;
  final String name;
  final double size;

  /// Addresses we have already failed to fetch, so a list of forty senders does
  /// not re-request forty dead URLs on every rebuild.
  static final Set<String> _missing = <String>{};

  static String gravatarUrl(String email, {int size = 160}) {
    final String hash =
        md5.convert(utf8.encode(email.trim().toLowerCase())).toString();
    return 'https://www.gravatar.com/avatar/$hash?d=404&s=$size';
  }

  static String initialsFor(String name, String email) {
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

  @override
  Widget build(BuildContext context) {
    final String address = email.trim();
    final Widget fallback = InitialsAvatar(
      initials: initialsFor(name, email),
      seed: address.isEmpty ? name : address,
      size: size,
    );

    // A Gravatar lookup sends a hash of the sender's address to a third party,
    // so it only happens when the user has left it switched on.
    if (!context.watch<Preferences>().showAvatars) return fallback;

    if (address.isEmpty || !address.contains('@') || _missing.contains(address)) {
      return fallback;
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.network(
          gravatarUrl(address, size: (size * 3).round()),
          width: size,
          height: size,
          fit: BoxFit.cover,
          // Show the initials until the picture is in, then swap.
          loadingBuilder: (BuildContext context, Widget child,
                  ImageChunkEvent? progress) =>
              progress == null ? child : fallback,
          errorBuilder: (BuildContext context, Object error,
              StackTrace? stackTrace) {
            // Remember the miss so the list does not retry it, but keep the
            // set bounded over a long session.
            if (_missing.length > 500) _missing.clear();
            _missing.add(address);
            return fallback;
          },
        ),
      ),
    );
  }
}
