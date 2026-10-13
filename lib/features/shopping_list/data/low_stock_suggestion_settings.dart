import '../../pantry/domain/models/pantry_item.dart';

const int minimumLowStockThreshold = 0;
const int maximumLowStockThreshold = 100;

final Map<PantryCategory, int> defaultLowStockThresholds = Map.unmodifiable({
  for (final category in PantryCategory.values) category: 1,
});

class LowStockSuggestionSettings {
  LowStockSuggestionSettings({
    this.enabled = true,
    Map<PantryCategory, int>? thresholds,
  }) : thresholds = Map.unmodifiable({
         ...defaultLowStockThresholds,
         ...?thresholds,
       });

  final bool enabled;
  final Map<PantryCategory, int> thresholds;

  int thresholdFor(PantryCategory category) =>
      thresholds[category] ?? defaultLowStockThresholds[category]!;

  double effectiveThresholdFor(PantryItem item) =>
      thresholdFor(item.category) * item.minQuantity;

  LowStockSuggestionSettings copyWith({
    bool? enabled,
    PantryCategory? category,
    int? threshold,
  }) {
    final nextThresholds = {...thresholds};
    if (category != null && threshold != null) {
      nextThresholds[category] = threshold.clamp(
        minimumLowStockThreshold,
        maximumLowStockThreshold,
      );
    }
    return LowStockSuggestionSettings(
      enabled: enabled ?? this.enabled,
      thresholds: nextThresholds,
    );
  }
}
