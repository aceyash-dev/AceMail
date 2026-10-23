/// The line above the list: where you are, and what is in it.
///
/// Pure, and in a util rather than in the widget, so the one thing that is easy
/// to get wrong — the hour boundaries — can be tested without a clock.
library;

/// Morning, afternoon, evening, from the clock, and the person's name when
/// there is one.
///
/// Never a bare "Hello": a greeting that does not know what time it is says
/// nothing, and the whole point of the line is that the app knows where it is.
///
/// The name is used as it came from the provider — not title-cased, not
/// shortened to a first name. Somebody whose mail says "Dr. Rao" is not "Dr",
/// and somebody who signs themselves "Yash Gupta" has chosen that.
String greetingFor(DateTime now, {String? name}) {
  final int hour = now.hour;
  final String greeting = hour < 12
      ? 'Good morning'
      : (hour < 17 ? 'Good afternoon' : 'Good evening');
  final String? trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty) return greeting;
  return '$greeting, $trimmed';
}

/// The folder, and what is waiting in it.
///
/// "nothing unread" rather than "0 unread": a count of zero is a number to read
/// and dismiss, and a sentence is not.
String folderSummary(String folder, int unseen) {
  if (unseen <= 0) return '$folder · nothing unread';
  return '$folder · $unseen unread';
}
