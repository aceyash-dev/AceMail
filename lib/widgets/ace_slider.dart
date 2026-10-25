import 'package:flutter/material.dart';

import '../theme/astryx_tokens.dart';

/// A Material 3 **Expressive** slider.
///
/// Flutter's own `Slider` is Material 3, and the expressive one is a different
/// drawing: a thin track, a gap either side of a tall rounded handle, and a stop
/// indicator sitting at the end of the track so the value has somewhere to
/// arrive. The handle is the part that carries it — it is deliberately much
/// taller than the track, which is what makes the control read as something you
/// *grab* rather than a line you click.
///
/// Written here rather than pulled in because the component library this app
/// uses for icons has no slider, and a dependency for one control is a
/// dependency to keep working for one control.
class AceSlider extends StatefulWidget {
  const AceSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.semanticLabel,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? semanticLabel;

  @override
  State<AceSlider> createState() => _AceSliderState();
}

class _AceSliderState extends State<AceSlider> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final double span = widget.max - widget.min;
    final double t = span <= 0 ? 0 : ((widget.value - widget.min) / span).clamp(0.0, 1.0);

    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: '${(t * 100).round()}%',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          void setFrom(double dx) {
            if (widget.onChanged == null || width <= 0) return;
            final double raw = (dx / width).clamp(0.0, 1.0);
            double next = widget.min + raw * span;
            if (widget.divisions != null && widget.divisions! > 0) {
              final double step = span / widget.divisions!;
              next = widget.min + (step * ((next - widget.min) / step).round());
            }
            widget.onChanged!(next.clamp(widget.min, widget.max));
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (TapDownDetails d) => setFrom(d.localPosition.dx),
            onHorizontalDragStart: (DragStartDetails d) {
              setState(() => _dragging = true);
              setFrom(d.localPosition.dx);
            },
            onHorizontalDragUpdate: (DragUpdateDetails d) => setFrom(d.localPosition.dx),
            onHorizontalDragEnd: (_) => setState(() => _dragging = false),
            child: SizedBox(
              height: 40,
              width: width,
              child: CustomPaint(
                painter: _AceSliderPainter(
                  t: t,
                  active: c.accent,
                  track: c.border,
                  handle: c.accent,
                  dragging: _dragging,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AceSliderPainter extends CustomPainter {
  _AceSliderPainter({
    required this.t,
    required this.active,
    required this.track,
    required this.handle,
    required this.dragging,
  });

  final double t;
  final Color active;
  final Color track;
  final Color handle;
  final bool dragging;

  @override
  void paint(Canvas canvas, Size size) {
    final double cy = size.height / 2;
    // The handle is a tall pill with a gap either side of it, and the track is
    // thin. The gap is what stops the filled part from touching the handle and
    // making one continuous shape.
    final double handleW = dragging ? 6 : 4;
    final double handleH = dragging ? 34 : 30;
    final double gap = 6;
    final double x = (t * (size.width - handleW)).clamp(0.0, size.width - handleW);
    final double centre = x + handleW / 2;

    final Paint trackPaint = Paint()..strokeCap = StrokeCap.round;
    trackPaint
      ..color = track
      ..strokeWidth = 4;
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), trackPaint);

    trackPaint
      ..color = active
      ..strokeWidth = 4;
    canvas.drawLine(
      Offset(0, cy),
      Offset((centre - gap).clamp(0.0, size.width), cy),
      trackPaint,
    );

    // The stop indicator: where the value arrives at the far end.
    canvas.drawCircle(
      Offset(size.width - 2, cy),
      2,
      Paint()..color = track,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centre, cy),
          width: handleW,
          height: handleH,
        ),
        Radius.circular(handleW / 2),
      ),
      Paint()..color = handle,
    );
  }

  @override
  bool shouldRepaint(covariant _AceSliderPainter old) =>
      old.t != t || old.dragging != dragging || old.active != active;
}
