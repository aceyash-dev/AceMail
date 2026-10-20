import 'package:flutter/material.dart';

import '../theme/astryx_tokens.dart';

/// A shimmering placeholder block.
///
/// A list that is still loading should look like the list that is coming —
/// same shapes, same rhythm — rather than a spinner in the middle of an empty
/// screen, which tells you nothing about what you are waiting for.
class AceSkeleton extends StatefulWidget {
  const AceSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AstryxRadius.inner,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<AceSkeleton> createState() => _AceSkeletonState();
}

class _AceSkeletonState extends State<AceSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        // Sweeps a lighter band across the block.
        final double t = _controller.value * 2 - 0.5;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: <Color>[
                c.surfaceHighest,
                c.backgroundMuted,
                c.surfaceHighest,
              ],
              stops: const <double>[0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Rows shaped like the message tiles that are about to arrive.
class MessageListSkeleton extends StatelessWidget {
  const MessageListSkeleton({super.key, this.rows = 7, this.avatarSize = 42});

  final int rows;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AstryxSpace.s4,
        vertical: AstryxSpace.s2,
      ),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows,
      itemBuilder: (BuildContext context, int index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AstryxSpace.s3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AceSkeleton(
              width: avatarSize,
              height: avatarSize,
              radius: AstryxRadius.container,
            ),
            const SizedBox(width: AstryxSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      // Varied widths, so the block does not read as a table.
                      Expanded(
                        flex: 3 + (index % 3),
                        child: const AceSkeleton(height: 12),
                      ),
                      const SizedBox(width: AstryxSpace.s4),
                      const AceSkeleton(width: 34, height: 12),
                    ],
                  ),
                  const SizedBox(height: AstryxSpace.s2),
                  AceSkeleton(
                    height: 12,
                    width: 140 + ((index * 37) % 120).toDouble(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The reader's own placeholder: a subject, a sender line, and body lines.
class MessageSkeleton extends StatelessWidget {
  const MessageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AstryxSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AceSkeleton(height: 26, width: 260, radius: AstryxRadius.element),
          const SizedBox(height: AstryxSpace.s5),
          const Row(
            children: <Widget>[
              AceSkeleton(width: 40, height: 40, radius: AstryxRadius.container),
              SizedBox(width: AstryxSpace.s3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AceSkeleton(height: 12, width: 120),
                  SizedBox(height: AstryxSpace.s2),
                  AceSkeleton(height: 10, width: 170),
                ],
              ),
            ],
          ),
          const SizedBox(height: AstryxSpace.s6),
          for (int i = 0; i < 6; i++) ...<Widget>[
            AceSkeleton(height: 12, width: 320 - (i * 29).toDouble()),
            const SizedBox(height: AstryxSpace.s3),
          ],
        ],
      ),
    );
  }
}
