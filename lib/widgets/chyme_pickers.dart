import 'package:flutter/material.dart';

import '../data/preferences.dart';
import '../services/chyme.dart';
import '../theme/ace_icons.dart';
import '../theme/astryx_theme.dart';
import '../theme/astryx_tokens.dart';
import '../util/ace_snack.dart';
import 'ace_icon_view.dart';
import 'settings_group.dart';

/// Choosing how Chyme writes, and which model writes it.
///
/// Both live here rather than in the settings screen because both are now
/// reachable from two places: the settings card, and the sheet's own header.
/// A setting that can be changed from the thing it changes is a setting people
/// actually change — going to Settings to switch tone, then back to the
/// conversation, is four taps to answer a question you had in the middle of
/// typing it.
Future<void> chooseChymeTone(
  BuildContext context,
  Preferences prefs,
) async {
  final ChymeTone? chosen = await showChoiceSheet<ChymeTone>(
    context,
    title: 'Tone',
    current: prefs.chymeTone,
    choices: <SettingsChoice<ChymeTone>>[
      for (final ChymeTone tone in ChymeTone.values)
        SettingsChoice<ChymeTone>(tone, tone.label, description: tone.instruction),
    ],
  );
  if (chosen != null) await prefs.setChymeTone(chosen);
}

/// Fetches what the endpoint offers and lets one be picked.
///
/// The fetch is the point: a model name typed from memory is a model name that
/// does not exist, and the error that follows blames the key.
Future<void> chooseChymeModel(
  BuildContext context,
  Preferences prefs,
) async {
  if (prefs.chymeEndpoint.trim().isEmpty) {
    AceSnack.show(context, 'Set the endpoint first.');
    return;
  }

  List<String> models;
  try {
    models = await Chyme.models(
      endpoint: prefs.chymeEndpoint,
      apiKey: prefs.chymeKey,
    );
  } catch (error) {
    if (!context.mounted) return;
    AceSnack.show(context, '$error');
    return;
  }
  if (!context.mounted) return;

  final String? chosen = await showChymeModelList(
    context,
    models,
    prefs.chymeModel,
  );
  if (chosen != null) await prefs.setChymeModel(chosen);
}

/// The model list, filterable. An endpoint can offer a hundred models, unsorted.
Future<String?> showChymeModelList(
  BuildContext context,
  List<String> models,
  String current,
) {
  final AstryxColors c = context.astryx;
  final TextEditingController filter = TextEditingController();

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => SafeArea(
      child: StatefulBuilder(
        builder: (BuildContext sheetContext, StateSetter setSheetState) {
          final String needle = filter.text.trim().toLowerCase();
          final List<String> shown = needle.isEmpty
              ? models
              : models
                  .where((String m) => m.toLowerCase().contains(needle))
                  .toList();
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
              ),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Model', style: AstryxText.heading4(c.textPrimary)),
                        const SizedBox(height: AstryxSpace.s2),
                        TextField(
                          controller: filter,
                          autofocus: true,
                          onChanged: (_) => setSheetState(() {}),
                          style: AstryxText.body(c.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search ${models.length} models',
                            prefixIcon: AceIconView(
                              icon: AceIcons.search,
                              size: 18,
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AstryxSpace.s5),
                      child: Text(
                        'Nothing matches that.',
                        style: AstryxText.body(c.textSecondary),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: shown.length,
                        itemBuilder: (BuildContext context, int i) {
                          final String model = shown[i];
                          final bool isCurrent = model == current;
                          return InkWell(
                            onTap: () => Navigator.of(sheetContext).pop(model),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AstryxSpace.s5,
                                vertical: AstryxSpace.s3,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      model,
                                      style: AstryxText.body(
                                        isCurrent ? c.accent : c.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (isCurrent)
                                    AceIconView(
                                      icon: AceIcons.checkCircle,
                                      size: 18,
                                      color: c.accent,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  ).whenComplete(filter.dispose);
}
