/// What a swipe across a message row does.
///
/// Kept in the model layer with no icon or colour attached, so the same value
/// can be stored in settings and drawn by the widget layer.
enum SwipeAction {
  none('None'),
  archive('Archive'),
  trash('Delete'),
  toggleRead('Read / unread'),
  flag('Flag / unflag');

  const SwipeAction(this.label);

  final String label;
}
