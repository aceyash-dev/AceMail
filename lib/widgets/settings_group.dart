import 'package:flutter/material.dart';

import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import 'astryx_widgets.dart';

/// One labelled group of settings, the way a settings screen is meant to read:
/// a small caption, then a card of related rows.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AstryxSpace.s5,
            AstryxSpace.s5,
            AstryxSpace.s5,
            AstryxSpace.s2,
          ),
          child: Text(
            title.toUpperCase(),
            style: AstryxText.caption(c.textSecondary).copyWith(letterSpacing: 0.8),
          ),
        ),
        AceSurface(
          radius: AstryxRadius.element,
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0)
                  Divider(height: 1, indent: AstryxSpace.s12, color: c.border),
                children[i],
              ],
            ],
          ),
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
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Shown before the chevron, the way "Language: English" reads.
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AstryxSpace.s4,
        vertical: AstryxSpace.s3,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: c.iconSecondary),
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
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(left: AstryxSpace.s2),
              child: Text(value!, style: AstryxText.supporting(c.textSecondary)),
            ),
          if (trailing != null) trailing!,
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(left: AstryxSpace.s1),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: c.iconDisabled,
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
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
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AstryxSpace.s4,
            vertical: AstryxSpace.s3,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: c.iconSecondary),
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
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// One option in a [showChoiceSheet].
class SettingsChoice<T> {
  const SettingsChoice(this.value, this.label, {this.description});

  final T value;
  final String label;
  final String? description;
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
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AstryxRadius.page),
      ),
    ),
    builder: (BuildContext sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AstryxSpace.s5,
              0,
              AstryxSpace.s5,
              AstryxSpace.s3,
            ),
            child: Text(title, style: AstryxText.heading3(c.textPrimary)),
          ),
          for (final SettingsChoice<T> choice in choices)
            ListTile(
              title: Text(choice.label, style: AstryxText.body(c.textPrimary)),
              subtitle: choice.description == null
                  ? null
                  : Text(
                      choice.description!,
                      style: AstryxText.supporting(c.textSecondary),
                    ),
              trailing: choice.value == current
                  ? Icon(Icons.check_rounded, color: c.accent)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(choice.value),
            ),
          const SizedBox(height: AstryxSpace.s3),
        ],
      ),
    ),
  );
}
