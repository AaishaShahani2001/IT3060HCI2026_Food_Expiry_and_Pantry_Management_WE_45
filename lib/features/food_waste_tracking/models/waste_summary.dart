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
  double get quantity => records.fold(0, (total, r) => total + r.quantity);
  double get estimatedValue =>
      records.fold(0, (total, r) => total + r.estimatedValue);
  bool get mixedUnits => records.map((r) => r.unit).toSet().length > 1;
  String get quantityDetail => mixedUnits
      ? 'Mixed units • numeric total'
      : records.isEmpty
      ? 'No quantities yet'
      : records.first.unit;
  // Compare record counts across full calendar periods; this is not a forecast.
  double? get trendPercent =>
      previousCount == 0 ? null : (count - previousCount) * 100 / previousCount;
  List<FoodWasteRecord> get recent => records.take(5).toList();
}

String wasteNumber(double value) => value == value.truncateToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();
String wasteMoney(double value) => 'Rs. ${value.toStringAsFixed(2)}';
String wasteDate(DateTime value) {
  final date = value.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
