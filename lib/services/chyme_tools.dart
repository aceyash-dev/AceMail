/// The tools Chyme may ask for, in one table.
///
/// The list used to exist twice: as prose inside the system prompt, and as a
/// `Map<String, ChymeTool>` inside the sheet. They are two descriptions of the
/// same contract written in two places, and the failure when they drift is
/// silent — the model is told about a tool the app does not have, or has a tool
/// it was never told about, and either way the answer is "I can't do that" for
/// something the app can do perfectly well.
///
/// One table, read by both: [promptList] is what the model is told, and
/// [mutates] is what decides whether a call runs or waits for a button.
class ChymeToolSpec {
  const ChymeToolSpec(
    this.name,
    this.argument,
    this.description, {
    this.mutates = false,
  });

  /// The name the model writes after `TOOL:`.
  final String name;

  /// What the argument looks like, for the prompt.
  final String argument;

  /// One line, imperative, in the model's own instructions.
  final String description;

  /// Whether this changes the mailbox.
  ///
  /// A mutating tool is **proposed**, never run: it arrives as a card with a
  /// button, because an assistant that archives your mail while you read the
  /// sentence about archiving it is an assistant you stop letting near your
  /// mail. Reading tools run, because reading is what it was asked to do.
  final bool mutates;

  /// The line the prompt shows for this tool.
  String get line => '  ${name.padRight(24)}$description';
}

abstract final class ChymeTools {
  /// Every tool, in the order the prompt lists them.
  ///
  /// Reading first, then the things that change mail, then contacts: the model
  /// reads its instructions in order, and the safest tools are the ones it
  /// should reach for first.
  static const List<ChymeToolSpec> all = <ChymeToolSpec>[
    ChymeToolSpec(
      'search',
      '<words>',
      'look through the mail already loaded',
    ),
    ChymeToolSpec(
      'read',
      '<uid>',
      'the whole body of one message',
    ),
    ChymeToolSpec(
      'star',
      '<uid>',
      'flag it',
      mutates: true,
    ),
    ChymeToolSpec(
      'unstar',
      '<uid>',
      'remove the flag',
      mutates: true,
    ),
    ChymeToolSpec(
      'seen',
      '<uid>',
      'mark it read',
      mutates: true,
    ),
    ChymeToolSpec(
      'archive',
      '<uid>',
      'move it out of the folder',
      mutates: true,
    ),
    ChymeToolSpec(
      'delete',
      '<uid>',
      'move it to the trash',
      mutates: true,
    ),
    ChymeToolSpec(
      'reply',
      '<uid> | <body>',
      'open a reply to it, in the person\'s composer',
      mutates: true,
    ),
    ChymeToolSpec(
      'contacts',
      '<words>',
      'look somebody up in their address book',
    ),
    ChymeToolSpec(
      'contact_add',
      '<Name> | <email>',
      'save them to it',
      mutates: true,
    ),
    ChymeToolSpec(
      'contact_block',
      '<email>',
      'keep their mail out of the list',
      mutates: true,
    ),
    ChymeToolSpec(
      'contact_delete',
      '<email>',
      'forget them entirely',
      mutates: true,
    ),
  ];

  /// The spec for [name], or null when the app has no such tool.
  static ChymeToolSpec? byName(String name) {
    for (final ChymeToolSpec spec in all) {
      if (spec.name == name) return spec;
    }
    return null;
  }

  /// Whether [name] changes mail, and so waits for a button.
  ///
  /// An unknown name is treated as mutating: a tool nobody wrote down must not
  /// be the one that runs without being asked about.
  static bool mutates(String name) => byName(name)?.mutates ?? true;

  /// Every name, for a test that pins the registry to the prompt.
  static List<String> get names =>
      <String>[for (final ChymeToolSpec spec in all) spec.name];

  /// The tool list as the prompt shows it.
  static String get promptList =>
      <String>[for (final ChymeToolSpec spec in all) spec.line].join('\n');
}
