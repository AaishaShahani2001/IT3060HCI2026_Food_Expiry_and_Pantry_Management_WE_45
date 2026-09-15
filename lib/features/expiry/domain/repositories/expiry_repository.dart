abstract class ExpiryRepository {
  /// Loads the current user's saved expiry alerts.
  Future<List<ExpiryAlert>> fetchAlerts();

  /// Creates or updates an expiry alert for a pantry item.
  Future<void> saveAlert(ExpiryAlert alert);

  /// Marks an expiry alert as read.
  Future<void> markAlertAsRead(String alertId);

  /// Deletes an expiry alert.
  Future<void> deleteAlert(String alertId);
}

/// Represents a persisted smart expiry alert.
class ExpiryAlert {
  const ExpiryAlert({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.itemName,
    required this.expiryDate,
    required this.daysUntilExpiry,
    required this.status,
    required this.priority,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String itemId;
  final String itemName;
  final DateTime expiryDate;
  final int daysUntilExpiry;
  final String status;
  final String priority;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'itemId': itemId,
      'itemName': itemName,
      'expiryDate': expiryDate.toIso8601String(),
      'daysUntilExpiry': daysUntilExpiry,
      'status': status,
      'priority': priority,
      'message': message,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ExpiryAlert.fromMap(String id, Map<String, dynamic> data) {
    return ExpiryAlert(
      id: id,
      userId: data['userId'] as String? ?? '',
      itemId: data['itemId'] as String? ?? '',
      itemName: data['itemName'] as String? ?? '',
      expiryDate: _parseDate(data['expiryDate']) ?? DateTime.now(),
      daysUntilExpiry: (data['daysUntilExpiry'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'unknown',
      priority: data['priority'] as String? ?? 'none',
      message: data['message'] as String? ?? '',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value;
    }

    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
