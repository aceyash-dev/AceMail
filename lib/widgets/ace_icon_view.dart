import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/ace_icons.dart';

/// One icon, drawn at the size it was asked for.
///
/// Every icon in the app goes through here rather than through `HugeIcon`
/// directly, for two reasons that are easy to get wrong in ninety places:
///
/// * **Optical size.** A Hugeicon fills its 24-unit grid much more completely
///   than a Material glyph does — a Material icon carries its own padding inside
///   the box. At the same nominal size, Hugeicons read about a fifth larger,
///   which is how a toolbar ends up looking like it is shouting.
/// * **Stroke weight.** The set is drawn for 24px. Below that a 1.5-unit stroke
///   goes thin and spidery, so it is nudged up a little at small sizes and left
///   alone at large ones.
class AceIconView extends StatelessWidget {
  const AceIconView({
    super.key,
    required this.icon,
    this.size = 20,
    this.color,
  });

  final AceIcon icon;
  final double size;
  final Color? color;

  /// Hugeicons are drawn fuller than Material glyphs; this is the correction.
  static const double opticalScale = 0.78;

  @override
  Widget build(BuildContext context) {
    final double drawn = size * opticalScale;

    // 1.5 units is right at 24px. Smaller icons need a touch more, larger ones
    // a touch less, so the weight stays even across the app.
    final double stroke = drawn >= 22
        ? 1.5
        : (1.5 * (22 / drawn)).clamp(1.5, 2.1);

    return HugeIcon(
      icon: icon,
      size: drawn,
      color: color,
      strokeWidth: stroke,
    );
  }
}
