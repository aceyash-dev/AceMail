import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/mail_providers.dart';

/// A provider's own logo, drawn inside a square of [size].
///
/// Bounded on purpose, and the reason is not obvious: `SvgPicture` reads a
/// `width` and a `height` together as "keep the height, and work the width out
/// from the artwork's aspect ratio". A provider wordmark — Yahoo's, iCloud's,
/// GMX's — is five or six times wider than it is tall, so drawn that way it came
/// out several times the width of the box it was given. A square with the
/// artwork contained inside it keeps every provider's mark the same footprint,
/// whatever shape its file is.
class ProviderMark extends StatelessWidget {
  const ProviderMark({super.key, required this.provider, required this.size});

  final MailProvider provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        provider.logo,
        fit: BoxFit.contain,
      ),
    );
  }
}
