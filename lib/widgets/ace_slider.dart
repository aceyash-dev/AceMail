import 'package:flutter/material.dart';

/// A slider, drawn by Material 3.
///
/// This used to be a hand-drawn copy of the Expressive slider — a thin track, a
/// gap either side of a tall handle, a stop indicator at the end — because
/// Flutter's `Slider` was still the 2023 design and a dependency for one control
/// is a dependency to keep working. Flutter's slider has been the updated M3 one
/// since 3.29, and a second implementation of a component the framework owns is
/// the thing that goes stale: it does not get the framework's fixes, its
/// accessibility, or its interaction details.
///
/// The 2024 appearance is opted into once, on the theme
/// (`SliderThemeData.year2023: false`), so every slider in the app is the same
/// M3 control and this widget is only the app's name for it.
class AceSlider extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final double span = max - min;
    final double clamped = span <= 0 ? min : value.clamp(min, max);

    return Semantics(
      label: semanticLabel,
      child: Slider(
        value: clamped,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }
}
