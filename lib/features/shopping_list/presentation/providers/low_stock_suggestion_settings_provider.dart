import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/theme_mode_provider.dart';
import '../../../pantry/domain/models/pantry_item.dart';
import '../../data/low_stock_suggestion_settings.dart';
import 'shopping_list_provider.dart';

final lowStockSuggestionSettingsProvider =
    NotifierProvider<
      LowStockSuggestionSettingsNotifier,
      LowStockSuggestionSettings
    >(LowStockSuggestionSettingsNotifier.new);

class LowStockSuggestionSettingsNotifier
    extends Notifier<LowStockSuggestionSettings> {
  static const _keyPrefix = 'low_stock_suggestions';
  String? _uid;

  @override
  LowStockSuggestionSettings build() {
    _uid = ref.watch(shoppingAuthUidProvider).asData?.value;
    final uid = _uid;
    final preferences = ref.watch(sharedPreferencesProvider);
    if (uid == null || preferences == null) {
      return LowStockSuggestionSettings();
    }

    final enabled = preferences.getBool('$_keyPrefix.$uid.enabled') ?? true;
    final storedThresholds = preferences.getString(
      '$_keyPrefix.$uid.thresholds',
    );
    final thresholds = <PantryCategory, int>{};
    if (storedThresholds != null) {
      try {
        final decoded = jsonDecode(storedThresholds);
        if (decoded is Map<String, dynamic>) {
          for (final category in PantryCategory.values) {
            final value = decoded[category.name];
            if (value is num) {
              thresholds[category] = value.toInt().clamp(
                minimumLowStockThreshold,
                maximumLowStockThreshold,
              );
            }
          }
        }
      } catch (_) {
        // Corrupt local preferences fall back to safe defaults.
      }
    }
    return LowStockSuggestionSettings(enabled: enabled, thresholds: thresholds);
  }

  void setEnabled(bool enabled) {
    final uid = _requireCurrentUser();
    state = state.copyWith(enabled: enabled);
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          ?.setBool('$_keyPrefix.$uid.enabled', enabled),
    );
  }

  void setThreshold(PantryCategory category, int threshold) {
    final uid = _requireCurrentUser();
    state = state.copyWith(category: category, threshold: threshold);
    unawaited(_persistThresholds(uid));
  }

  Future<void> resetThresholds() async {
    final uid = _requireCurrentUser();
    state = LowStockSuggestionSettings(enabled: state.enabled);
    await _persistThresholds(uid);
  }

  Future<void> _persistThresholds(String uid) async {
    final encoded = jsonEncode({
      for (final entry in state.thresholds.entries) entry.key.name: entry.value,
    });
    await ref
        .read(sharedPreferencesProvider)
        ?.setString('$_keyPrefix.$uid.thresholds', encoded);
  }

  String _requireCurrentUser() {
    final current = ref.read(shoppingAuthUidProvider).asData?.value;
    if (_uid == null || current != _uid) {
      throw StateError('Your account changed. Please try again.');
    }
    return _uid!;
  }
}
