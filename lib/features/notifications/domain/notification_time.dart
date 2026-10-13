/// Relative label for a notification timestamp.
///
/// The stored value stays an absolute [DateTime]. This is display-only.
String formatNotificationAge(DateTime createdAt, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final createdDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
  final dayGap = today.difference(createdDay).inDays;
  if (dayGap >= 2) return '$dayGap days ago';
  if (dayGap == 1) return 'Yesterday';

  final difference = now.difference(createdAt);
  if (difference.isNegative || difference.inSeconds < 60) {
    return 'Just now';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} min ago';
  }
  final hours = difference.inHours;
  if (hours < 1) return 'Just now';
  return '$hours hr ago';
}
