import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../data/mail_providers.dart';
import '../data/preferences.dart';
import '../services/local_avatars.dart';
import '../services/bimi.dart';
import '../util/initials.dart';
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
    this.isSelf = false,
  });

  final String email;
  final String name;
  final double size;

  /// Your own account. Its picture is looked up even when third-party lookups
  /// are off: it is your address, and you are the one looking at it.
  final bool isSelf;

  /// Addresses we have already failed to fetch, so a list of forty senders does
  /// not re-request forty dead URLs on every rebuild.
  static final Set<String> _missing = <String>{};

  static String gravatarUrl(String email, {int size = 160}) {
    final String hash =
        md5.convert(utf8.encode(email.trim().toLowerCase())).toString();
    return 'https://www.gravatar.com/avatar/$hash?d=404&s=$size';
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
  void initState() {
    super.initState();
    // A picture set in Settings has to appear on rows that were already built.
    LocalAvatars.revision.addListener(_onPictureChanged);
  }

  @override
  void dispose() {
    LocalAvatars.revision.removeListener(_onPictureChanged);
    super.dispose();
  }

  void _onPictureChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Deliberately *not* gated on the pictures setting. BIMI is a DNS record
    // the sender's own domain publishes, and the logo is served from that same
    // domain — a domain that already knows it emailed you. Nothing is told to a
    // third party, so it is not something to opt into. Gravatar is the opposite,
    // and stays behind the switch.
    if (_looked) return;
    _looked = true;
    unawaited(_resolveBimi());
  }

  Future<void> _resolveBimi() async {
    final String address = widget.email.trim();
    if (address.isEmpty || !address.contains('@')) return;

    String? url = _bimi[address];
    if (!_bimi.containsKey(address)) {
      url = await BimiResolver.logoFor(address);
      // Same as the resolver's own cache: the oldest goes, not all of them.
      while (_bimi.length > 300) {
        _bimi.remove(_bimi.keys.first);
      }
      _bimi[address] = url;
    }

    if (!mounted || url == null) return;
    setState(() => _logoUrl = url);
  }

  /// The mark of the provider this address belongs to, if it is one we know.
  Widget? _providerMark(String address) {
    final int at = address.lastIndexOf('@');
    if (at < 0) return null;
    final String domain = address.substring(at + 1).toLowerCase();
    for (final MailProvider provider in kProviderChoices) {
      if (!provider.domains.contains(domain)) continue;
      return SvgPicture.asset(
        provider.logo,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final String address = widget.email.trim();
    // Your own address with nothing published for it: the provider's own mark.
    //
    // Your face would be better, and initials are a worse answer than either —
    // the mark at least says *which account* this is, which is the other thing
    // an avatar is for. Only for your own address: a sender's provider mark is
    // noise, and there are forty of them in a list.
    final Widget fallback = (widget.isSelf ? _providerMark(address) : null) ??
        InitialsAvatar(
          initials: initialsFor(widget.name, widget.email),
          seed: address.isEmpty ? widget.name : address,
          size: widget.size,
        );

    if (address.isEmpty || !address.contains('@')) return fallback;

    // A picture somebody chose for this address, before anything looked up.
    // Local wins deliberately: a choice is an answer, a lookup is a guess, and
    // somebody who uploads a photo and then sees an identicon anyway would be
    // right to call it a bug. Not gated on the third-party setting — nothing
    // leaves the device to draw it.
    final String? local = LocalAvatars.pathFor(address);
    if (local != null) {
      return _clipped(
        Image.file(
          File(local),
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          cacheWidth:
              (widget.size * MediaQuery.devicePixelRatioOf(context)).round(),
          errorBuilder: (BuildContext context, Object error,
                  StackTrace? stackTrace) =>
              fallback,
        ),
      );
    }

    // The sender's own published logo, shown whenever there is one.
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

    // Gravatar is the opt-in part: it tells a third party which addresses are
    // in your mail. Your own address is the exception — you already know it.
    final bool allowed =
        widget.isSelf || context.watch<Preferences>().showAvatars;
    if (!allowed) return fallback;
    if (MailAvatar._missing.contains(address)) return fallback;

    return _clipped(
      Image.network(
        // Decoded at the size it is drawn, not at whatever the server sent. A
        // 200px avatar in a 40px row is four times the pixels for none of the
        // detail, on every row of a scrolling list.
        cacheWidth: (widget.size * MediaQuery.devicePixelRatioOf(context)).round(),
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
  /// A circle, because a face is not a rounded square.
  ///
  /// The squircle was the app's own shape and it reads well for a *card*; on an
  /// avatar it reads as an unfinished box, and the thing inside it is a person.
  Widget _clipped(Widget child) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: ClipOval(child: child),
      );
}
