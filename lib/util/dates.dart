const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _two(int value) => value.toString().padLeft(2, '0');

/// Compact date for the message list: time today, day + month this year,
/// day + month + year otherwise.
String formatListDate(DateTime? date) {
  if (date == null) return '';
  final DateTime local = date.toLocal();
  final DateTime now = DateTime.now();
  final bool today = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  if (today) return '${_two(local.hour)}:${_two(local.minute)}';
  if (local.year == now.year) {
    return '${local.day} ${_months[local.month - 1]}';
  }
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

/// Full date for the reader header.
String formatFullDate(DateTime? date) {
  if (date == null) return '';
  final DateTime local = date.toLocal();
  const List<String> weekdays = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  return '${weekdays[local.weekday - 1]}, ${local.day} '
      '${_months[local.month - 1]} ${local.year}, '
      '${_two(local.hour)}:${_two(local.minute)}';
}

String formatBytes(int bytes) {
  const List<String> units = <String>['B', 'KB', 'MB', 'GB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final String text =
      unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}
