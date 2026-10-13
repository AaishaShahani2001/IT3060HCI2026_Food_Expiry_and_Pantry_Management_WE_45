import 'repositories/expiry_repository.dart';

/// Firestore document id for one user's expiry alert about one pantry item.
///
/// Personal and shared pantry items both use this id. Two users tracking the
/// same shared item get two documents, `userA_item` and `userB_item`.
String buildExpiryAlertId(String userId, String itemId) {
  return '${userId}_$itemId';
}

/// Rewrites [alert] so it is stored under [userId], never under a bare item id.
ExpiryAlert scopedExpiryAlert({
  required ExpiryAlert alert,
  required String userId,
}) {
  return alert.copyWith(
    id: buildExpiryAlertId(userId, alert.itemId),
    userId: userId,
  );
}

/// One alert per pantry item. A `{userId}_{itemId}` document wins over an
/// older document whose id is only the item id.
List<ExpiryAlert> dedupeExpiryAlerts(Iterable<ExpiryAlert> alerts) {
  final byItem = <String, ExpiryAlert>{};
  for (final alert in alerts) {
    final key = alert.itemId.isNotEmpty ? alert.itemId : alert.id;
    final current = byItem[key];
    if (current == null || _preferAlert(alert, current)) {
      byItem[key] = alert;
    }
  }
  return byItem.values.toList();
}

bool _isCanonical(ExpiryAlert alert) {
  if (alert.userId.isEmpty || alert.itemId.isEmpty) return false;
  return alert.id == buildExpiryAlertId(alert.userId, alert.itemId);
}

bool _preferAlert(ExpiryAlert candidate, ExpiryAlert current) {
  final candidateCanonical = _isCanonical(candidate);
  final currentCanonical = _isCanonical(current);
  if (candidateCanonical != currentCanonical) return candidateCanonical;
  return true;
}
