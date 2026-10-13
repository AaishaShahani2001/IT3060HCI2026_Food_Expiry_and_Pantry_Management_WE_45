import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../pantry/domain/pantry_scope.dart';

/// Pantry and expiry events shown in the Home notification panel.
///
/// Firestore stores the enum name (`expiringSoon`), never a display label,
/// icon, colour, or formatted relative time.
enum AppNotificationType {
  expiringSoon,
  expired,
  lowStock;

  static AppNotificationType? tryParse(Object? raw) {
    if (raw is! String) return null;
    for (final value in AppNotificationType.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.alertKey,
    required this.isRead,
    required this.createdAt,
    this.pantryItemId,
    this.pantryItemName,
    this.expiryDate,
    this.pantryScope,
    this.pantryName,
    this.readAt,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final AppNotificationType type;
  final String title;
  final String message;
  final String? pantryItemId;
  final String? pantryItemName;
  final DateTime? expiryDate;

  /// `personal` or `shared` for notifications created with a known pantry.
  /// Null on older documents, which keep their original wording.
  final String? pantryScope;

  /// Household name captured when a shared notification was created.
  final String? pantryName;

  /// Stable id for one alert event. Also used as the Firestore document id.
  final String alertKey;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? deletedAt;

  bool get isActive => deletedAt == null;

  /// Title plus pantry context when this notification recorded one.
  ///
  /// Older notifications have no [pantryScope] and keep [title] unchanged.
  String get displayTitle {
    final scope = PantryScope.tryParse(pantryScope, pantryName);
    if (scope == null) return title;
    return scope.notificationTitle(title);
  }

  AppNotification copyWith({
    bool? isRead,
    DateTime? readAt,
    DateTime? deletedAt,
    bool clearReadAt = false,
    bool clearDeletedAt = false,
  }) {
    return AppNotification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      pantryItemId: pantryItemId,
      pantryItemName: pantryItemName,
      expiryDate: expiryDate,
      pantryScope: pantryScope,
      pantryName: pantryName,
      alertKey: alertKey,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      readAt: clearReadAt ? null : readAt ?? this.readAt,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    );
  }

  /// Returns null when the document is missing the fields the panel needs.
  static AppNotification? tryParse(String id, Map<String, dynamic> data) {
    final type = AppNotificationType.tryParse(data['type']);
    final userId = data['userId'];
    final title = data['title'];
    final message = data['message'];
    if (type == null || userId is! String || userId.isEmpty) return null;
    if (title is! String || title.isEmpty) return null;
    if (message is! String) return null;

    final alertKey = data['alertKey'];
    final stableKey = alertKey is String && alertKey.isNotEmpty ? alertKey : id;
    // Older expiry documents encode the date in their stable event key.
    final dateMatch = RegExp(
      r'_(\d{4}-\d{2}-\d{2})(?:_(\d{4}))?$',
    ).firstMatch(stableKey);
    final fallbackExpiry = dateMatch == null
        ? null
        : DateTime.tryParse(
            '${dateMatch.group(1)}'
            '${dateMatch.group(2) == null ? '' : 'T${dateMatch.group(2)!.substring(0, 2)}:${dateMatch.group(2)!.substring(2)}:00'}',
          );
    return AppNotification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      pantryItemId: _optionalString(data['pantryItemId']),
      pantryItemName: _optionalString(data['pantryItemName']),
      pantryScope: _storedPantryScope(data['pantryScope']),
      pantryName: _optionalString(data['pantryName']),
      alertKey: stableKey,
      expiryDate:
          parseNotificationDate(data['expiryDate']) ??
          (type == AppNotificationType.lowStock || dateMatch == null
              ? null
              : fallbackExpiry),
      isRead: data['isRead'] == true,
      createdAt:
          parseNotificationDate(data['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      readAt: parseNotificationDate(data['readAt']),
      deletedAt: parseNotificationDate(data['deletedAt']),
    );
  }
}

String? _storedPantryScope(Object? value) {
  final scope = _optionalString(value)?.toLowerCase();
  if (scope == 'personal' || scope == 'shared' || scope == 'family') {
    return scope == 'family' ? 'shared' : scope;
  }
  return null;
}

String? _optionalString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Accepts Firestore timestamps, ISO strings, and epoch numbers.
///
/// Null, blank, and non-finite values become null instead of throwing.
DateTime? parseNotificationDate(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed);
  }
  if (value is num) {
    if (value is double && !value.isFinite) return null;
    final raw = value.toInt();
    if (raw <= 0) return null;
    final millis = raw > 100000000000 ? raw : raw * 1000;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
  return null;
}
