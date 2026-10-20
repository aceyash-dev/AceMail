import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../services/bimi.dart';
import 'astryx_widgets.dart';

/// A sender's picture.
///
/// In order of preference: the sender's **BIMI** logo — published by the domain
/// itself, so it is the brand's own mark rather than a guess — then Gravatar,
/// then the initials chip, which is also what you get offline or for the many
/// people who have neither.
///
/// Both remote lookups are gated on the same setting, because both tell a third
/// party which domains are in your mail.
class MailAvatar extends StatefulWidget {
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
  State<MailAvatar> createState() => _MailAvatarState();
}

class _MailAvatarState extends State<MailAvatar> {
  /// address -> BIMI logo URL, or null when the domain publishes none.
  static final Map<String, String?> _bimi = <String, String?>{};

  String? _logoUrl;
  bool _looked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Gated on the setting, so switching pictures off means no lookup at all —
    // not a lookup whose result is thrown away.
    if (_looked || !context.read<Preferences>().showAvatars) return;
    _looked = true;
    unawaited(_resolveBimi());
  }

  Future<void> _resolveBimi() async {
    final String address = widget.email.trim();
    if (address.isEmpty || !address.contains('@')) return;

    String? url = _bimi[address];
    if (!_bimi.containsKey(address)) {
      url = await BimiResolver.logoFor(address);
      if (_bimi.length > 300) _bimi.clear();
      _bimi[address] = url;
    }

    if (!mounted || url == null) return;
    setState(() => _logoUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    final String address = widget.email.trim();
    final Widget fallback = InitialsAvatar(
      initials: MailAvatar.initialsFor(widget.name, widget.email),
      seed: address.isEmpty ? widget.name : address,
      size: widget.size,
    );

    if (!context.watch<Preferences>().showAvatars) return fallback;
    if (address.isEmpty || !address.contains('@')) return fallback;

    final String? logo = _logoUrl;
    if (logo != null) {
      return _clipped(
        SvgPicture.network(
          logo,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          placeholderBuilder: (BuildContext context) => fallback,
          errorBuilder: (BuildContext context, Object error,
                  StackTrace? stackTrace) =>
              fallback,
        ),
      );
    }

    if (MailAvatar._missing.contains(address)) return fallback;

    return _clipped(
      Image.network(
        MailAvatar.gravatarUrl(address, size: (widget.size * 3).round()),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        // Show the initials until the picture is in, then swap.
        loadingBuilder:
            (BuildContext context, Widget child, ImageChunkEvent? progress) =>
                progress == null ? child : fallback,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
          // Remember the miss so the list does not retry it, but keep the set
          // bounded over a long session.
          if (MailAvatar._missing.length > 500) MailAvatar._missing.clear();
          MailAvatar._missing.add(address);
          return fallback;
        },
      ),
    );
  }

  /// A continuous corner rather than a circle, to match the initials tile and
  /// the rest of the expressive shape language.
  Widget _clipped(Widget child) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: ClipPath(
          clipper: const AceSquircleClipper(),
          child: child,
        ),
      );
}
