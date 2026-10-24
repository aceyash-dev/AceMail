// ignore_for_file: unused_import
// Part of the AceMail Astryx design system.
import 'dart:async';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../../theme/ace_icons.dart';
import '../../theme/astryx_theme.dart';
import '../../theme/astryx_tokens.dart';
import '../../util/haptics.dart';
import '../shape_morph.dart';
import '../ace_icon_view.dart';
import 'ace_press_helpers.dart';
import 'ace_icon_button.dart';

/// A floating pill toolbar — the expressive M3 toolbar, docked at the bottom of
/// a surface where a thumb can reach it.
class AceToolbarAction {
  const AceToolbarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.destructive = false,
  });

  final AceIcon icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final bool destructive;
}

class AceToolbar extends StatelessWidget {
  const AceToolbar({super.key, required this.actions});

  final List<AceToolbarAction> actions;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s2),
      decoration: BoxDecoration(
        color: c.backgroundPopover,
        borderRadius: BorderRadius.circular(AstryxRadius.full),
        border: Border.all(color: c.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.overlay.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final AceToolbarAction action in actions)
            AceIconButton(
              icon: action.icon,
              tooltip: action.tooltip,
              onPressed: action.onPressed,
              selected: action.selected,
              variant: action.destructive
                  ? AceIconButtonVariant.danger
                  : (action.selected
                      ? AceIconButtonVariant.tonal
                      : AceIconButtonVariant.standard),
            ),
        ],
      ),
    );
  }
}

