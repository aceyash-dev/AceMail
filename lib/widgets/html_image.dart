import 'package:flutter/material.dart';

import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';

/// An image from an HTML mail.
///
/// Remote images are not fetched unless the reader asks for them: loading one
/// tells the sender's server that the message was opened, from this address, at
/// this time, which is what a tracking pixel is. Until then the picture is a
/// placeholder the size it claims to be, so the text around it does not jump.
class HtmlImage extends StatelessWidget {
  const HtmlImage({
    super.key,
    this.source,
    this.alt = '',
    this.loadRemote = false,
  });

  final String? source;
  final String alt;
  final bool loadRemote;

  /// Anything taller than this is scaled down. A mail that ships a 4000px
  /// screenshot should not take over the reader.
  static const double _maxHeight = 320;

  bool get _remote =>
      loadRemote &&
      source != null &&
      (source!.startsWith('https://') || source!.startsWith('http://'));

  @override
  Widget build(BuildContext context) {
    if (!_remote) return _placeholder(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _maxHeight),
        child: Image.network(
          source!,
          fit: BoxFit.contain,
          // A broken or blocked image falls back to the same placeholder as an
          // unloaded one, so a failure never leaves a hole in the layout.
          errorBuilder: (BuildContext context, _, __) => _placeholder(context),
          loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? progress) =>
              progress == null ? child : _placeholder(context, loading: true),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, {bool loading = false}) {
    final AstryxColors c = context.astryx;
    final String label = alt.isNotEmpty
        ? alt
        : (loading ? 'Loading image…' : 'Image');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AstryxSpace.s3,
          vertical: AstryxSpace.s2,
        ),
        decoration: BoxDecoration(
          color: c.backgroundMuted,
          borderRadius: BorderRadius.circular(AstryxRadius.element),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              loading ? Icons.hourglass_empty_rounded : Icons.image_outlined,
              size: 15,
              color: c.iconSecondary,
            ),
            const SizedBox(width: AstryxSpace.s2),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AstryxText.supporting(c.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
