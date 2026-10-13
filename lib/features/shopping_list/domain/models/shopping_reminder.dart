class ShoppingReminder {
  ShoppingReminder({required DateTime date, required List<DateTime> times})
    : date = DateTime(date.year, date.month, date.day),
      times = List.unmodifiable([...times]..sort());

  final DateTime date;
  final List<DateTime> times;

  int get count => times.length;

  bool hasFutureTime(DateTime now) => times.any((time) => time.isAfter(now));

  Map<String, Object> toJson() => {
    'date': date.millisecondsSinceEpoch,
    'times': times.map((time) => time.millisecondsSinceEpoch).toList(),
  };

  factory ShoppingReminder.fromJson(Map<String, Object?> json) {
    final dateValue = json['date'];
    final timesValue = json['times'];
    if (dateValue is! int || timesValue is! List) {
      throw const FormatException('Invalid Shopping reminder data.');
    }
    final times = <DateTime>[];
    for (final value in timesValue) {
      if (value is! int) {
        throw const FormatException('Invalid Shopping reminder time.');
      }
      times.add(DateTime.fromMillisecondsSinceEpoch(value));
    }
    return ShoppingReminder(
      date: DateTime.fromMillisecondsSinceEpoch(dateValue),
      times: times,
    );
  }
}

String? shoppingReminderValidationMessage(
  ShoppingReminder reminder,
  DateTime now,
) {
  if (reminder.count < 1 || reminder.count > 3) {
    return 'Choose between 1 and 3 reminder times.';
  }
  final today = DateTime(now.year, now.month, now.day);
  if (reminder.date.isBefore(today)) {
    return 'Choose today or a future date.';
  }
  final uniqueTimes = reminder.times
      .map((time) => time.millisecondsSinceEpoch)
      .toSet();
  if (uniqueTimes.length != reminder.times.length) {
    return 'Choose a different time for each reminder.';
  }
  for (final time in reminder.times) {
    final timeDate = DateTime(time.year, time.month, time.day);
    if (timeDate != reminder.date) {
      return 'All reminder times must be on the selected date.';
    }
    if (!time.isAfter(now)) {
      return 'Choose reminder times that are still in the future.';
    }
  }
  return null;
}
