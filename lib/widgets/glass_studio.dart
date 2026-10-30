import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import 'ace_glass.dart';
import 'ace_icon_view.dart';
import 'ace_slider.dart';
import 'astryx_widgets.dart';

/// The glass, with dials.
///
/// The material was one design decision made once — a blur radius and a tint —
/// and it is the kind of decision people disagree about: on a bright wallpaper
/// the default is too thin, and on a dark one it is a grey film over everything.
/// So it is adjustable, with a preview that is the real material rather than a
/// picture of it: the card below is built by the same code every other surface
/// uses, over a backdrop that shows what is being blurred.
class GlassStudio extends StatefulWidget {
  const GlassStudio({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => const GlassStudio(),
    );
  }

  @override
  State<GlassStudio> createState() => _GlassStudioState();
}

class _GlassStudioState extends State<GlassStudio> {
  static const double _defaultBlur = 24;
  static const double _defaultTint = 0.72;

  /// The backdrop the preview sits on: a gradient with something in it, because
  /// a blur over a flat colour is a flat colour.
  Widget _backdrop(AstryxColors c) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            c.accent,
            c.tertiary,
            c.backgroundSurface,
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 24,
            top: 22,
            child: AceIconView(
              icon: AceIcons.mail,
              size: 46,
              color: c.onAccent.withValues(alpha: 0.55),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 14,
            child: AceIconView(
              icon: AceIcons.inbox,
              size: 64,
              color: c.onAccent.withValues(alpha: 0.35),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AstryxSpace.s4),
              child: AceGlass.material(
                context,
                radius: BorderRadius.circular(AstryxRadius.container),
                bordered: true,
                child: Padding(
                  padding: const EdgeInsets.all(AstryxSpace.s4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Ace Mail',
                        style: AstryxText.bodyStrong(c.textPrimary),
                      ),
                      const SizedBox(height: AstryxSpace.s1),
                      Text(
                        'This is the material, not a picture of it.',
                        style: AstryxText.supporting(c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    final Preferences prefs = context.watch<Preferences>();

    final double blur = prefs.glassBlur ?? _defaultBlur;
    final double tint = prefs.glassTint ?? _defaultTint;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.only(bottom: AstryxSpace.s6),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AstryxSpace.s5,
              0,
              AstryxSpace.s5,
              AstryxSpace.s3,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Glass studio', style: AstryxText.heading2(c.textPrimary)),
                      const SizedBox(height: AstryxSpace.s1),
                      Text(
                        AceGlass.capable
                            ? 'Blur, tint, and whether the glass is smoked or frosted.'
                            : 'This device cannot blur a backdrop, so the surfaces '
                                'stay flat. The dials below do nothing here.',
                        style: AstryxText.supporting(c.textSecondary),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => prefs.resetGlass(),
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AstryxRadius.container),
              child: _backdrop(c),
            ),
          ),
          const SizedBox(height: AstryxSpace.s5),
          _Dial(
            label: 'Blur',
            value: '${blur.round()}',
            child: AceSlider(
              value: blur,
              min: 0,
              max: 40,
              semanticLabel: 'Blur radius',
              onChanged: (double value) => prefs.setGlassBlur(value),
            ),
          ),
          _Dial(
            label: 'Tint',
            value: '${(tint * 100).round()}%',
            child: AceSlider(
              value: tint,
              min: 0.2,
              max: 1,
              semanticLabel: 'Tint strength',
              onChanged: (double value) => prefs.setGlassTint(value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AstryxSpace.s2),
            child: SwitchListTile(
              value: prefs.glassInvert,
              onChanged: prefs.setGlassInvert,
              secondary: AceIconView(
                icon: AceIcons.palette,
                color: c.iconSecondary,
              ),
              title: Text('Invert the tint', style: AstryxText.body(c.textPrimary)),
              subtitle: Text(
                'Smoked glass instead of frosted: the same surface, the colour '
                'turned inside out.',
                style: AstryxText.supporting(c.textSecondary),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AstryxSpace.s5,
              AstryxSpace.s4,
              AstryxSpace.s5,
              0,
            ),
            child: AceButton(
              label: 'Done',
              variant: AceButtonVariant.primary,
              expand: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

/// One labelled dial with its value beside it.
class _Dial extends StatelessWidget {
  const _Dial({required this.label, required this.value, required this.child});

  final String label;
  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AstryxColors c = context.astryx;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AstryxSpace.s5,
        AstryxSpace.s3,
        AstryxSpace.s5,
        AstryxSpace.s1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The value beside the name, not at the far edge of the row. Stretched
          // apart, "Blur" and "24" read as two unrelated things with a screen
          // between them, and the number you are dragging towards is the one
          // place you want your eye to stay.
          Row(
            children: <Widget>[
              Text(label, style: AstryxText.body(c.textPrimary)),
              const SizedBox(width: AstryxSpace.s2),
              Text(value, style: AstryxText.supporting(c.textSecondary)),
            ],
          ),
          const SizedBox(height: AstryxSpace.s0_5),
          child,
        ],
      ),
    );
  }
}
