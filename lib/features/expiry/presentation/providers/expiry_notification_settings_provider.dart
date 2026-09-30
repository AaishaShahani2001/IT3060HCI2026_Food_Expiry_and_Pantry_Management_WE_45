import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/theme_mode_provider.dart';

class ExpiryNotificationSettingsState {
  const ExpiryNotificationSettingsState({
    this.notificationsEnabled = true,
    this.expiringSoonEnabled = true,
    this.expiredItemsEnabled = true,
    this.useFirstEnabled = true,
    this.daysBefore = 3,
    this.notificationTime = const TimeOfDay(hour: 9, minute: 0),
    this.frequency = 'Daily',
  });

  final bool notificationsEnabled;
  final bool expiringSoonEnabled;
  final bool expiredItemsEnabled;
  final bool useFirstEnabled;
  final int daysBefore;
  final TimeOfDay notificationTime;
  final String frequency;

  ExpiryNotificationSettingsState copyWith({
    bool? notificationsEnabled,
    bool? expiringSoonEnabled,
    bool? expiredItemsEnabled,
    bool? useFirstEnabled,
    int? daysBefore,
    TimeOfDay? notificationTime,
    String? frequency,
  }) {
    return ExpiryNotificationSettingsState(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      expiringSoonEnabled: expiringSoonEnabled ?? this.expiringSoonEnabled,
      expiredItemsEnabled: expiredItemsEnabled ?? this.expiredItemsEnabled,
      useFirstEnabled: useFirstEnabled ?? this.useFirstEnabled,
      daysBefore: daysBefore ?? this.daysBefore,
      notificationTime: notificationTime ?? this.notificationTime,
      frequency: frequency ?? this.frequency,
    );
  }
}

class ExpiryNotificationSettingsNotifier
    extends Notifier<ExpiryNotificationSettingsState> {
  static const String _keyNotificationsEnabled = 'expiry_notif_enabled';
  static const String _keyExpiringSoon = 'expiry_notif_expiring_soon';
  static const String _keyExpiredItems = 'expiry_notif_expired_items';
  static const String _keyUseFirst = 'expiry_notif_use_first';
  static const String _keyDaysBefore = 'expiry_notif_days_before';
  static const String _keyHour = 'expiry_notif_hour';
  static const String _keyMinute = 'expiry_notif_minute';
  static const String _keyFrequency = 'expiry_notif_frequency';

  @override
  ExpiryNotificationSettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs == null) {
      return const ExpiryNotificationSettingsState();
    }

    return ExpiryNotificationSettingsState(
      notificationsEnabled: prefs.getBool(_keyNotificationsEnabled) ?? true,
      expiringSoonEnabled: prefs.getBool(_keyExpiringSoon) ?? true,
      expiredItemsEnabled: prefs.getBool(_keyExpiredItems) ?? true,
      useFirstEnabled: prefs.getBool(_keyUseFirst) ?? true,
      daysBefore: prefs.getInt(_keyDaysBefore) ?? 3,
      notificationTime: TimeOfDay(
        hour: prefs.getInt(_keyHour) ?? 9,
        minute: prefs.getInt(_keyMinute) ?? 0,
      ),
      frequency: prefs.getString(_keyFrequency) ?? 'Daily',
    );
  }

  Future<void> saveSettings(ExpiryNotificationSettingsState newState) async {
    state = newState;
    final prefs =
        ref.read(sharedPreferencesProvider) ??
        await SharedPreferences.getInstance();

    await prefs.setBool(
      _keyNotificationsEnabled,
      newState.notificationsEnabled,
    );
    await prefs.setBool(_keyExpiringSoon, newState.expiringSoonEnabled);
    await prefs.setBool(_keyExpiredItems, newState.expiredItemsEnabled);
    await prefs.setBool(_keyUseFirst, newState.useFirstEnabled);
    await prefs.setInt(_keyDaysBefore, newState.daysBefore);
    await prefs.setInt(_keyHour, newState.notificationTime.hour);
    await prefs.setInt(_keyMinute, newState.notificationTime.minute);
    await prefs.setString(_keyFrequency, newState.frequency);
  }
}

final expiryNotificationSettingsProvider =
    NotifierProvider<
      ExpiryNotificationSettingsNotifier,
      ExpiryNotificationSettingsState
    >(ExpiryNotificationSettingsNotifier.new);
