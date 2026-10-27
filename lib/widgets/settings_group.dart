import 'package:flutter/material.dart';

import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import 'astryx_widgets.dart';
import 'ace_icon_view.dart';

/// One labelled group of settings, the way a settings screen is meant to read:
/// a tracked caption, then a card of related rows.
class SettingsSection extends StatefulWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.initiallyOpen = true,
    this.onToggle,
  });

  final String title;
  final List<Widget> children;

  /// Open by default. A settings screen where every category starts folded is
  /// a list of headings you have to open one at a time to find anything in.
  final bool initiallyOpen;

  /// Called with the new state when somebody folds or unfolds the section.
  ///
  /// The widget itself keeps no memory beyond its own build: where the decision
  /// is written down is the screen's business, and a settings section that
  /// reached into storage itself would be a widget that cannot be used twice.
  final ValueChanged<bool>? onToggle;

  @override
  State<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<SettingsSection> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The heading is the handle. Tapping a category folds it, which is how
        // you get from fourteen sections to the two you came here for.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() => _open = !_open);
            widget.onToggle?.call(_open);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AstryxSpace.s6,
              AstryxSpace.s6,
              AstryxSpace.s6,
              AstryxSpace.s2,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.title.toUpperCase(),
                    style: AstryxText.label(c.textSecondary).copyWith(
                      letterSpacing: 1.4,
                      fontSize: AstryxType.sXs,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0 : -0.25,
                  duration: AstryxMotion.fast,
                  curve: AstryxMotion.emphasized,
                  child: AceIconView(
                    icon: AceIcons.chevronDown,
                    size: 16,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: AstryxMotion.medium,
          curve: AstryxMotion.emphasized,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AstryxSpace.s3,
                  ),
                  child: AceSurface(
                    squircle: true,
                    padding: const EdgeInsets.symmetric(
                      vertical: AstryxSpace.s1,
                    ),
                    child: Column(
                      children: <Widget>[
                        for (int i = 0; i < widget.children.length; i++)
                          ...<Widget>[
                            if (i > 0)
                              Divider(
                                height: 1,
                                indent: AstryxSpace.s11,
                                endIndent: AstryxSpace.s3,
                                color: c.border,
                              ),
                            widget.children[i],
                          ],
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// A tappable settings row: icon, title, optional subtitle, trailing value.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.trailing,
    this.leading,
  });

  final AceIcon icon;
  final String title;

  /// Shown in place of the icon, when a row needs something an icon cannot say
  /// — a provider's own colour, for instance.
  final Widget? leading;
  final String? subtitle;

  /// Shown before the chevron, the way "Theme: Light" reads.
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return AceListTile(
      onTap: onTap,
      title: title,
      subtitle: subtitle,
      padding: const EdgeInsets.symmetric(
        horizontal: AstryxSpace.s3,
        vertical: AstryxSpace.s3,
      ),
      leading: leading ??
          AceIconView(icon: icon, size: 20, color: c.iconSecondary),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (value != null)
            Text(value!, style: AstryxText.supporting(c.textSecondary)),
          if (trailing != null) trailing!,
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(left: AstryxSpace.s1),
              child: AceIconView(icon: 
                AceIcons.chevronRight,
                size: 20,
                color: c.iconDisabled,
              ),
            ),
        ],
      ),
    );
  }
}

/// A settings row whose control is a switch. The whole row is the target.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leading,
  });

  final AceIcon icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Shown in place of the icon, for a row whose subject has a mark of its own.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return AceSpringy(
      onTap: () => onChanged(!value),
      builder: (BuildContext context, double press, bool hover) {
        final double t = press.clamp(0.0, 1.0);
        return Transform.scale(
          scale: 1 - 0.015 * press,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 1),
            padding: const EdgeInsets.symmetric(
              horizontal: AstryxSpace.s3,
              vertical: AstryxSpace.s3,
            ),
            decoration: BoxDecoration(
              color: hover ? c.surfaceHighest : Colors.transparent,
              borderRadius: BorderRadius.circular(
                AstryxRadius.container - (AstryxRadius.container - AstryxRadius.inner) * t,
              ),
            ),
            child: Row(
              children: <Widget>[
                leading ??
                    AceIconView(icon: icon, size: 20, color: c.iconSecondary),
                const SizedBox(width: AstryxSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: AstryxText.body(c.textPrimary)),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AstryxSpace.s0_5),
                          child: Text(
                            subtitle!,
                            style: AstryxText.supporting(c.textSecondary),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AstryxSpace.s2),
                // Material 3 Expressive's switch: a tick when it is on, a
                // cross when it is off. The mark is the point — a switch's
                // position is a thing you read, a tick is a thing you know.
                AceSwitch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One option in a [showChoiceSheet].
class SettingsChoice<T> {
  const SettingsChoice(
    this.value,
    this.label, {
    this.description,
    this.leading,
  });

  final T value;
  final String label;
  final String? description;

  /// A picture or a colour beside the name. A list of drawings that shows only
  /// their names is a list you have to guess from.
  final Widget? leading;
}

/// A sheet of mutually exclusive options. Returns the chosen value, or null if
/// the user backed out.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<SettingsChoice<T>> choices,
  required T current,
}) {
  final AstryxColors c = context.astryx;

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: c.backgroundSurface,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AstryxSpace.s6,
              AstryxSpace.s2,
              AstryxSpace.s6,
              AstryxSpace.s3,
            ),
            child: Text(title, style: AstryxText.heading2(c.textPrimary)),
          ),
          // Scrollable, and bounded: a list of choices grows with the app, and
          // eight tones plus a ninth was enough to overflow the sheet on a
          // short phone — a choice nobody can scroll to is a choice removed.
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s3),
              child: Column(
                children: <Widget>[
                  for (final SettingsChoice<T> choice in choices)
                    AceListTile(
                      onTap: () => Navigator.of(sheetContext).pop(choice.value),
                      title: choice.label,
                      subtitle: choice.description,
                      leading: choice.leading,
                      selected: choice.value == current,
                      trailing: choice.value == current
                          ? AceIconView(icon: AceIcons.check, color: c.accent)
                          : null,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AstryxSpace.s4),
        ],
      ),
    ),
  );
}
