/// Local wall-clock instant for an expiry reminder.
///
/// The calendar day is [reminderDays] before the expiry's local date.
/// The clock time is the saved notification hour and minute. The expiry
/// item's own time is not used.
DateTime expiryReminderAt({
  required DateTime expiry,
  required int reminderDays,
  required int hour,
  required int minute,
}) {
  final localExpiry = expiry.toLocal();
  final alertDay = DateTime(
    localExpiry.year,
    localExpiry.month,
    localExpiry.day,
  ).subtract(Duration(days: reminderDays));
  return DateTime(alertDay.year, alertDay.month, alertDay.day, hour, minute);
}
