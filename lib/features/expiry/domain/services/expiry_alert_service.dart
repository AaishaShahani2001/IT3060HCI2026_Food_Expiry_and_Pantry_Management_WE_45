import 'package:firebase_auth/firebase_auth.dart';

import '../../../pantry/domain/models/pantry_item.dart';
import '../../data/repositories/firestore_expiry_repository.dart';
import '../expiry_alert_id.dart';
import '../repositories/expiry_repository.dart';
import 'expiry_notification_service.dart';
import 'expiry_service.dart';

class ExpiryAlertService {
  ExpiryAlertService({
    ExpiryService? expiryService,
    ExpiryRepository? repository,
    FirebaseAuth? auth,
    required ExpiryNotificationService notificationService,
  }) : _expiryService = expiryService ?? const ExpiryService(),
       _repository = repository ?? FirestoreExpiryRepository(),
       _auth = auth ?? FirebaseAuth.instance,
       _notificationService = notificationService;

  final ExpiryService _expiryService;
  final ExpiryRepository _repository;
  final FirebaseAuth _auth;
  final ExpiryNotificationService _notificationService;

  /// Creates or updates Firestore alerts for pantry items that
  /// currently require expiry attention.
  ///
  /// Items without an expiry date or items that are still fresh
  /// do not generate alerts.
  Future<void> synchronizeAlerts(Iterable<PantryItem> items) async {
    final user = _auth.currentUser;
    final uid = user?.uid ?? "guest";

    for (final item in items) {
      final priority = _expiryService.alertPriority(item);

      if (priority == 'none') {
        continue;
      }

      final daysUntilExpiry = _expiryService.daysUntilExpiry(item);

      if (daysUntilExpiry == null || item.expiryDate == null) {
        continue;
      }

      final message = _expiryService.smartAlertMessage(item);

      if (message == null) {
        continue;
      }

      final status = _statusFromDays(daysUntilExpiry);

      final alert = ExpiryAlert(
        id: buildExpiryAlertId(uid, item.id),
        userId: uid,
        itemId: item.id,
        itemName: item.name,
        expiryDate: item.expiryDate!,
        daysUntilExpiry: daysUntilExpiry,
        status: status,
        priority: priority,
        message: message,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await _repository.saveAlert(alert);
      await _notificationService.showExpiryNotification(
        title: "${item.name} expiry alert",

        body: message,
      );
    }
  }

  String _statusFromDays(int days) {
    if (days < 0) {
      return 'expired';
    }

    if (days <= 3) {
      return 'expiring_soon';
    }

    return 'fresh';
  }
}
