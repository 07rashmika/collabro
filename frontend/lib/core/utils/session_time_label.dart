const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _time(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

/// Human-friendly label for just the day part, e.g. "Today", "Tomorrow", or "Jul 20".
String sessionDateLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(local.year, local.month, local.day);
  final dayDiff = target.difference(today).inDays;

  if (dayDiff == 0) return 'Today';
  if (dayDiff == 1) return 'Tomorrow';
  return '${_months[local.month - 1]} ${local.day}';
}

/// Human-friendly label for a scheduled session time, e.g.
/// "Today, 3:00 PM", "Tomorrow, 10:00 AM", or "Jul 20, 3:00 PM".
String sessionTimeLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${sessionDateLabel(local)}, ${_time(local)}';
}
