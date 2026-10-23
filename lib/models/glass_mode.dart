/// How see-through the floating surfaces are.
///
/// In its own file rather than in the widget that draws the material, because
/// it is a *setting*: a stored value that the preferences decode and the
/// settings screen shows. A widget is not where a stored value lives.
enum GlassMode {
  auto('Automatic'),
  always('Always'),
  never('Never');

  const GlassMode(this.label);

  final String label;
}
