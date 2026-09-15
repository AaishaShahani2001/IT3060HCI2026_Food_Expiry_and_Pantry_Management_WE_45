import 'package:firebase_auth/firebase_auth.dart';

import '../../../pantry/domain/models/pantry_item.dart';
import '../../data/repositories/firestore_expiry_repository.dart';
import '../../domain/repositories/expiry_repository.dart';
import 'expiry_service.dart';

class ExpiryAlertService {
  ExpiryAlertService({
    ExpiryService? expiryService,
    ExpiryRepository? repository,
    FirebaseAuth? auth,
  }) : _expiryService = expiryService ?? const ExpiryService(),
       _repository = repository ?? FirestoreExpiryRepository(),
       _auth = auth ?? FirebaseAuth.instance;

  final ExpiryService _expiryService;
  final ExpiryRepository _repository;
  final FirebaseAuth _auth;

  /// Creates or updates Firestore alerts for pantry items that
  /// currently require expiry attention.
  ///
  /// Items without an expiry date or items that are still fresh
  /// do not generate alerts.
  Future<void> synchronizeAlerts(Iterable<PantryItem> items) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('No authenticated user found.');
    }

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
        id: _alertId(user.uid, item.id),
        userId: user.uid,
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

  String _alertId(String userId, String itemId) {
    return '${userId}_$itemId';
  }
}
