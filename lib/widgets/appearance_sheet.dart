import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/preferences.dart';
import '../theme/astryx_tokens.dart';
import '../theme/custom_appearance.dart';

/// The sheet behind Settings → Custom colour & font.
///
/// Everything here applies live: the accent is written to the preferences on
/// every change, so the app behind the sheet re-themes as the sliders move
/// rather than on dismissal.
Future<void> showAppearanceSheet(BuildContext context, Preferences prefs) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => _AppearanceSheet(prefs: prefs),
  );
}

class _AppearanceSheet extends StatefulWidget {
  const _AppearanceSheet({required this.prefs});

  final Preferences prefs;

  @override
  State<_AppearanceSheet> createState() => _AppearanceSheetState();
}

class _AppearanceSheetState extends State<_AppearanceSheet> {
  late Color _colour;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _colour = widget.prefs.customAccent ?? widget.prefs.accent.seed;
  }

  /// Picks a font file, copies it somewhere it will survive, and registers it.
  ///
  /// The copy matters: the picker hands back a path that can disappear — a
  /// document provider, a download folder the user cleans out — and a keyboard
  /// or an app that falls back to the system face halfway through a session
  /// looks broken rather than unconfigured.
  Future<void> _chooseFont() async {
    setState(() => _busy = true);
    try {
      const XTypeGroup fonts = XTypeGroup(
        label: 'Fonts',
        extensions: <String>['ttf', 'otf', 'ttc'],
      );
      final XFile? picked = await openFile(acceptedTypeGroups: <XTypeGroup>[fonts]);
      if (picked == null) return;

      final Directory dir = await getApplicationSupportDirectory();
      final File target = File(
        '${dir.path}/custom_font_${DateTime.now().millisecondsSinceEpoch}'
        '${picked.name.contains('.') ? '.${picked.name.split('.').last}' : '.ttf'}',
      );
      await target.writeAsBytes(await picked.readAsBytes(), flush: true);

      final String? family = await CustomAppearance.installFont(target.path);
      if (family == null) {
        // Not a font, whatever the extension said.
        await target.delete();
        return;
      }
      await widget.prefs.setCustomFontPath(target.path);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Preferences prefs = context.watch<Preferences>();
    final AstryxColors c = context.astryx;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Custom colour & font', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'The accent applies to the whole app, Chyme included. '
              'The font replaces the one every screen is set in.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),

            Text('Accent', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _colour,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 12),
                Text(CustomAppearance.encodeColour(_colour)),
                const Spacer(),
                TextButton(
                  onPressed: prefs.customAccent == null
                      ? null
                      : () async {
                          await prefs.setCustomAccent(null);
                          if (mounted) {
                            setState(() => _colour = prefs.accent.seed);
                          }
                        },
                  child: const Text('Reset'),
                ),
              ],
            ),
            _ChannelSlider(
              label: 'Hue',
              value: HSVColor.fromColor(_colour).hue,
              max: 360,
              onChanged: (double v) => _setColour(
                HSVColor.fromColor(_colour).withHue(v).toColor(),
              ),
            ),
            _ChannelSlider(
              label: 'Saturation',
              value: HSVColor.fromColor(_colour).saturation,
              max: 1,
              onChanged: (double v) => _setColour(
                HSVColor.fromColor(_colour).withSaturation(v).toColor(),
              ),
            ),
            _ChannelSlider(
              label: 'Brightness',
              value: HSVColor.fromColor(_colour).value,
              max: 1,
              onChanged: (double v) => _setColour(
                HSVColor.fromColor(_colour).withValue(v).toColor(),
              ),
            ),

            const SizedBox(height: 20),
            Text('Font', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    prefs.customFontPath == null
                        ? 'The app\u2019s own face'
                        : prefs.customFontPath!.split(Platform.pathSeparator).last,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _chooseFont,
                  child: Text(_busy ? 'Reading\u2026' : 'Choose file'),
                ),
                if (prefs.customFontPath != null)
                  TextButton(
                    onPressed: () => prefs.setCustomFontPath(null),
                    child: const Text('Reset'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '.ttf and .otf files. The copy is kept inside the app, so clearing '
              'your downloads does not change how the app looks.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _setColour(Color colour) {
    setState(() => _colour = colour);
    widget.prefs.setCustomAccent(colour);
  }
}

class _ChannelSlider extends StatelessWidget {
  const _ChannelSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 84,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0, max),
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
