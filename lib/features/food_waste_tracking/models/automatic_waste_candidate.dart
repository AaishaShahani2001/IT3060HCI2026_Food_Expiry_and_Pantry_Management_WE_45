import 'dart:convert';

import 'food_waste_record.dart';

class AutomaticWasteCandidate {
  const AutomaticWasteCandidate({required this.uid, required this.record});

  final String uid;
  final FoodWasteRecord record;

  String get eventId => record.id!;
}

DateTime wasteExpiryDate(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime wasteExpiryEventTime(DateTime value) {
  final expiry = wasteExpiryDate(value);
  return DateTime(expiry.year, expiry.month, expiry.day + 1);
}

String automaticWasteEventId(String pantryItemId, DateTime expiryDate) {
  if (pantryItemId.trim().isEmpty || pantryItemId.contains('/')) {
    throw ArgumentError('Invalid pantry item ID.');
  }
  final expiry = wasteExpiryDate(expiryDate);
  final date =
      '${expiry.year.toString().padLeft(4, '0')}-'
      '${expiry.month.toString().padLeft(2, '0')}-'
      '${expiry.day.toString().padLeft(2, '0')}';
  final encoded = base64Url.encode(utf8.encode('$pantryItemId|$date'));
  return 'auto-expiry-${encoded.replaceAll('=', '')}';
}
