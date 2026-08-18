import 'package:intl/intl.dart';

List<String> _months = List.generate(
  12,
  (index) => DateFormat.MMM().format(DateTime(2024, index + 1)),
);

String _time(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

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

String sessionTimeLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${sessionDateLabel(local)}, ${_time(local)}';
}
