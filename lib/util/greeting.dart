/// The line above the list: where you are, and what is in it.
///
/// Pure, and in a util rather than in the widget, so the one thing that is easy
/// to get wrong — the hour boundaries — can be tested without a clock.
library;

/// Morning, afternoon, evening, from the clock.
///
/// Never a bare "Hello": a greeting that does not know what time it is says
/// nothing, and the whole point of the line is that the app knows where it is.
String greetingFor(DateTime now) {
  final int hour = now.hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// The folder, and what is waiting in it.
///
/// "nothing unread" rather than "0 unread": a count of zero is a number to read
/// and dismiss, and a sentence is not.
String folderSummary(String folder, int unseen) {
  if (unseen <= 0) return '$folder · nothing unread';
  return '$folder · $unseen unread';
}
