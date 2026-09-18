import 'food_waste_record.dart';

enum WastePeriod { today, week, month }

extension WastePeriodLabel on WastePeriod {
  String get label => switch (this) {
    WastePeriod.today => 'Today',
    WastePeriod.week => 'This Week',
    WastePeriod.month => 'This Month',
  };
  String get comparisonLabel => switch (this) {
    WastePeriod.today => 'yesterday',
    WastePeriod.week => 'previous week',
    WastePeriod.month => 'previous month',
  };
}

class WasteDateRange {
  const WasteDateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
  bool contains(DateTime value) =>
      !value.toLocal().isBefore(start) && value.toLocal().isBefore(end);

  // Local calendar periods, Monday-start weeks, exclusive next-period boundary.
  // Calendar constructors (not 24-hour durations) also handle DST transitions.
  static WasteDateRange forPeriod(
    WastePeriod period,
    DateTime now, {
    bool previous = false,
  }) {
    final local = now.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    return switch (period) {
      WastePeriod.today => WasteDateRange(
        DateTime(day.year, day.month, day.day - (previous ? 1 : 0)),
        DateTime(day.year, day.month, day.day + (previous ? 0 : 1)),
      ),
      WastePeriod.week => WasteDateRange(
        DateTime(
          day.year,
          day.month,
          day.day - day.weekday + 1 - (previous ? 7 : 0),
        ),
        DateTime(
          day.year,
          day.month,
          day.day - day.weekday + 8 - (previous ? 7 : 0),
        ),
      ),
      WastePeriod.month => WasteDateRange(
        DateTime(day.year, day.month - (previous ? 1 : 0)),
        DateTime(day.year, day.month + (previous ? 0 : 1)),
      ),
    };
  }
}

List<FoodWasteRecord> newestWasteFirst(Iterable<FoodWasteRecord> records) =>
    records.toList()..sort((a, b) {
      final date = b.wastedAt.compareTo(a.wastedAt);
      return date != 0 ? date : (a.id ?? '').compareTo(b.id ?? '');
    });

class WasteSummary {
  WasteSummary(List<FoodWasteRecord> all, this.period, DateTime now)
    : records = newestWasteFirst(
        all.where(
          (r) => WasteDateRange.forPeriod(period, now).contains(r.wastedAt),
        ),
      ),
      previousCount = all
          .where(
            (r) => WasteDateRange.forPeriod(
              period,
              now,
              previous: true,
            ).contains(r.wastedAt),
          )
          .length;
  final WastePeriod period;
  final List<FoodWasteRecord> records;
  final int previousCount;
  int get count => records.length;
  double get estimatedValue =>
      records.fold(0, (total, r) => total + r.estimatedValue);
  // Never add quantities with incompatible units. Sort for stable summaries.
  Map<String, double> get quantitiesByUnit {
    final totals = <String, double>{};
    for (final record in records) {
      totals.update(
        record.unit,
        (v) => v + record.quantity,
        ifAbsent: () => record.quantity,
      );
    }
    return {
      for (final unit in totals.keys.toList()..sort()) unit: totals[unit]!,
    };
  }

  bool get mixedUnits => quantitiesByUnit.length > 1;
  String get quantityValue => mixedUnits
      ? '${quantitiesByUnit.length} units'
      : wasteNumber(quantitiesByUnit.values.firstOrNull ?? 0);
  String get quantityDetail {
    final totals = quantitiesByUnit;
    if (totals.isEmpty) return 'No quantities yet';
    if (totals.length == 1) return totals.keys.single;
    return [
      ...totals.entries.take(3).map((e) => '${wasteNumber(e.value)} ${e.key}'),
      if (totals.length > 3) '+${totals.length - 3} more',
    ].join(' • ');
  }

  // Compare record counts across full calendar periods; this is not a forecast.
  double? get trendPercent => previousCount == 0
      ? (count == 0 ? 0 : null)
      : (count - previousCount) * 100 / previousCount;
  String get trendValue {
    final trend = trendPercent;
    if (trend == null) return 'No previous data';
    if (trend == 0) return 'No change';
    return '${trend < 0 ? '↓' : '↑'} ${wasteNumber(double.parse(trend.abs().toStringAsFixed(1)))}%';
  }

  String get trendDetail {
    final trend = trendPercent;
    if (trend == null) return 'Record more waste to see trends';
    if (count == 0 && previousCount == 0) return 'No records in either period';
    return '${trend == 0
        ? 'Same record count as'
        : trend < 0
        ? 'Fewer records than'
        : 'More records than'} ${period.comparisonLabel}';
  }

  // Require two records; report ties explicitly rather than implying a winner.
  String? get reasonInsight {
    if (count < 2) return null;
    final totals = <String, int>{};
    for (final record in records) {
      totals.update(record.reason, (n) => n + 1, ifAbsent: () => 1);
    }
    final largest = totals.values.reduce((a, b) => a > b ? a : b);
    final reasons = totals.keys.where((r) => totals[r] == largest).toList()
      ..sort();
    if (reasons.length > 1) {
      return 'Reasons are tied. Look for patterns as you track.';
    }
    final tip = switch (reasons.single) {
      'Expired' => 'Check dates before shopping.',
      'Spoiled' => 'Review storage and use fresh food sooner.',
      'Not Used' => 'Plan meals around what you already have.',
      'Cooked Too Much' => 'Try smaller portions next time.',
      _ => 'Review these records to spot a pattern.',
    };
    return 'Most common reason: ${reasons.single} ($largest/$count). $tip';
  }

  List<FoodWasteRecord> get recent => records.take(5).toList();
}

String wasteNumber(double value) => value == value.truncateToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();
String wasteMoney(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  return 'Rs. $whole${parts.length == 1 || parts.last == '00' ? '' : '.${parts.last}'}';
}

String wasteRelativeDate(DateTime value, DateTime now) {
  if (WasteDateRange.forPeriod(WastePeriod.today, now).contains(value)) {
    return 'Today';
  }
  if (WasteDateRange.forPeriod(
    WastePeriod.today,
    now,
    previous: true,
  ).contains(value)) {
    return 'Yesterday';
  }
  return wasteDate(value);
}

String wasteDate(DateTime value) {
  final date = value.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
