import 'package:flutter/material.dart';

import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/haptics.dart';
import 'ace_icon_view.dart';

/// One entry in the floating bar.
class AceNavItem<T> {
  const AceNavItem({
    required this.value,
    required this.icon,
    required this.label,
  });

  final T value;
  final AceIcon icon;
  final String label;
}

/// A floating navigation bar, in the shape Material 3 Expressive draws one.
///
/// It floats: a pill of its own surface, clear of the bottom edge, with the
/// page visible on both sides of it. A bar welded to the bottom edge is a
/// region of the screen; a bar that floats is a thing on the screen, which is
/// the difference the shape is there to make.
///
/// The current item is the only one that says its name. Two labels always on
/// screen is a bar that reads like a table of contents; one label, moving,
/// reads like a choice that has been made.
class AceFloatingNav<T> extends StatelessWidget {
  const AceFloatingNav({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final List<AceNavItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AstryxSpace.s4,
        0,
        AstryxSpace.s4,
        AstryxSpace.s4,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AstryxSpace.s2,
            vertical: AstryxSpace.s2,
          ),
          decoration: BoxDecoration(
            color: c.backgroundCard,
            borderRadius: BorderRadius.circular(AstryxRadius.pill),
            border: Border.all(color: c.border),
            // A soft, wide shadow rather than a hard one: the bar should look
            // lifted off the page, not cut into it.
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.textPrimary.withValues(alpha: 0.10),
                blurRadius: 18,
                spreadRadius: -6,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final AceNavItem<T> item in items)
                _NavButton<T>(
                  item: item,
                  selected: item.value == value,
                  onTap: () {
                    if (item.value == value) return;
                    unawaited(AceHaptics.select());
                    onChanged(item.value);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton<T> extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AceNavItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AstryxMotion.of(const Duration(milliseconds: 300)),
          curve: AstryxMotion.emphasized,
          padding: const EdgeInsets.symmetric(
            horizontal: AstryxSpace.s3,
            vertical: AstryxSpace.s2,
          ),
          decoration: BoxDecoration(
            // The selection is a fill, which is the only way the stroke-only
            // icon set can say "this one" without a second set of glyphs.
            color: selected ? c.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AstryxRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AceIconView(
                icon: item.icon,
                size: 22,
                color: selected ? c.onAccent : c.iconSecondary,
              ),
              // The label is animated rather than switched: it grows out of the
              // icon and collapses back into it, so the bar does not jump.
              AnimatedSize(
                duration: AstryxMotion.of(const Duration(milliseconds: 300)),
                curve: AstryxMotion.emphasized,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: AstryxSpace.s2),
                        child: Text(
                          item.label,
                          style: AstryxText.label(c.onAccent),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
