import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/food_waste_record.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/models/waste_summary.dart';
import 'support/waste_test_session.dart';

void main() {
  test(
    'model serializes six fields, Timestamp and generated ID separately',
    () {
      final record = draft();
      final map = record.toMap();
      expect(map.keys.toSet(), {
        'itemName',
        'quantity',
        'unit',
        'reason',
        'estimatedValue',
        'wastedAt',
      });
      expect(map['wastedAt'], isA<Timestamp>());
      final loaded = FoodWasteRecord.fromMap('generated', map);
      expect(loaded.id, 'generated');
      expect(loaded.toMap(), map);
      expect(loaded.copyWith(itemName: 'Rice').id, 'generated');
    },
  );
  test(
    'validates required fields and finite positive quantity/nonnegative value',
    () {
      for (final invalid in [
        draft(name: ' '),
        draft(quantity: 0),
        draft(quantity: -1),
        draft(quantity: double.nan),
        draft(quantity: double.infinity),
        draft(value: -1),
        draft(value: double.infinity),
        draft(unit: ''),
        draft().copyWith(reason: ''),
      ]) {
        expect(invalid.toMap, throwsArgumentError);
      }
      expect(draft(quantity: 0.25, value: 0).toMap()['quantity'], 0.25);
    },
  );
  test('malformed Firestore documents are rejected', () {
    for (final field in draft().toMap().keys) {
      expect(
        () => FoodWasteRecord.fromMap('id', {...draft().toMap(), field: null}),
        throwsFormatException,
      );
    }
    expect(
      () => FoodWasteRecord.fromMap('id', {...draft().toMap(), 'quantity': -2}),
      throwsFormatException,
    );
  });
  test('Today includes midnight but excludes tomorrow and yesterday', () {
    final records = [
      draft(date: DateTime(2026, 9, 15, 23, 59)),
      draft(date: DateTime(2026, 9, 16)),
      draft(date: DateTime(2026, 9, 16, 23, 59)),
      draft(date: DateTime(2026, 9, 17)),
    ];
    final summary = WasteSummary(records, WastePeriod.today, wasteTestNow);
    expect(summary.count, 2);
    expect(summary.previousCount, 1);
  });
  test('This Week starts Monday and excludes following Monday', () {
    final records = [
      draft(date: DateTime(2026, 9, 13)),
      draft(date: DateTime(2026, 9, 14)),
      draft(date: DateTime(2026, 9, 20, 23, 59)),
      draft(date: DateTime(2026, 9, 21)),
    ];
    expect(WasteSummary(records, WastePeriod.week, wasteTestNow).count, 2);
  });
  test('This Month uses calendar boundaries including leap years', () {
    final now = DateTime(2024, 3, 1);
    final records = [
      draft(date: DateTime(2024, 2, 29)),
      draft(date: now),
      draft(date: DateTime(2024, 4, 1)),
    ];
    final summary = WasteSummary(records, WastePeriod.month, now);
    expect(summary.count, 1);
    expect(summary.previousCount, 1);
    final previous = WasteDateRange.forPeriod(
      WastePeriod.month,
      DateTime(2026, 1, 2),
      previous: true,
    );
    expect(previous.start, DateTime(2025, 12, 1));
    expect(previous.end, DateTime(2026, 1, 1));
  });
  test('summary counts, mixed quantities and Sri Lankan value total', () {
    final summary = WasteSummary(
      [draft(value: 100), draft(quantity: 0.5, unit: 'kg', value: 25.5)],
      WastePeriod.today,
      wasteTestNow,
    );
    expect(summary.count, 2);
    expect(summary.quantitiesByUnit, {'kg': 0.5, 'pcs': 2});
    expect(summary.quantityValue, '2 units');
    expect(summary.mixedUnits, isTrue);
    expect(summary.quantityDetail, '0.5 kg • 2 pcs');
    expect(summary.estimatedValue, 125.5);
    expect(wasteMoney(summary.estimatedValue), 'Rs. 125.50');
  });
  test('trend compares record counts and lower is less waste', () {
    final old = draft(date: DateTime(2026, 9, 15));
    expect(
      WasteSummary(
        [draft(), old, old],
        WastePeriod.today,
        wasteTestNow,
      ).trendPercent,
      -50,
    );
    expect(
      WasteSummary(
        [draft(), draft(), old],
        WastePeriod.today,
        wasteTestNow,
      ).trendPercent,
      100,
    );
    expect(
      WasteSummary([old], WastePeriod.today, wasteTestNow).trendPercent,
      -100,
    );
  });
  test('no baseline is safe; both empty periods mean no change', () {
    expect(
      WasteSummary([draft()], WastePeriod.today, wasteTestNow).trendPercent,
      isNull,
    );
    expect(WasteSummary([], WastePeriod.today, wasteTestNow).trendPercent, 0);
    expect(
      WasteSummary([], WastePeriod.today, wasteTestNow).trendValue,
      'No change',
    );
    final noBaseline = WasteSummary([draft()], WastePeriod.today, wasteTestNow);
    expect(noBaseline.trendValue, 'No previous data');
    expect(noBaseline.trendDetail, 'Record more waste to see trends');
  });
  test(
    'single unit adds only that unit; many units have a compact breakdown',
    () {
      final single = WasteSummary(
        [
          draft(quantity: 2, unit: 'bottle'),
          draft(quantity: 3, unit: 'bottle'),
        ],
        WastePeriod.today,
        wasteTestNow,
      );
      expect(single.quantityValue, '5');
      expect(single.quantityDetail, 'bottle');
      final mixed = WasteSummary(
        [
          draft(quantity: 2, unit: 'bottle'),
          draft(quantity: 1.5, unit: 'kg'),
          draft(quantity: 4, unit: 'pcs'),
          draft(unit: 'pack'),
          draft(unit: 'g'),
        ],
        WastePeriod.today,
        wasteTestNow,
      );
      expect(mixed.quantityValue, '5 units');
      expect(mixed.quantityDetail, '2 bottle • 2 g • 1.5 kg • +2 more');
    },
  );
  test('money uses grouped whole values or cents rounded to two places', () {
    expect(wasteMoney(0), 'Rs. 0');
    expect(wasteMoney(1000), 'Rs. 1,000');
    expect(wasteMoney(12500), 'Rs. 12,500');
    expect(wasteMoney(450.5), 'Rs. 450.50');
    expect(wasteMoney(1234.567), 'Rs. 1,234.57');
    expect(wasteMoney(999.999), 'Rs. 1,000');
    expect(wasteMoney(987654321250), 'Rs. 987,654,321,250');
    // Display formatting must not round small quantities in an edit form.
    expect(wasteNumber(0.001), '0.001');
  });
  test(
    'reason insights are selected-period only with explicit tie handling',
    () {
      final summary = WasteSummary(
        [
          draft(),
          draft(),
          draft().copyWith(reason: 'Spoiled'),
          ...List.generate(
            5,
            (_) =>
                draft(date: DateTime(2026, 9, 1)).copyWith(reason: 'Spoiled'),
          ),
        ],
        WastePeriod.today,
        wasteTestNow,
      );
      expect(
        summary.reasonInsight,
        'Most common reason: Expired (2/3). Check dates before shopping.',
      );
      expect(
        WasteSummary([], WastePeriod.today, wasteTestNow).reasonInsight,
        isNull,
      );
      expect(
        WasteSummary([draft()], WastePeriod.today, wasteTestNow).reasonInsight,
        isNull,
      );
      expect(
        WasteSummary(
          [draft(), draft().copyWith(reason: 'Other')],
          WastePeriod.today,
          wasteTestNow,
        ).reasonInsight,
        contains('tied'),
      );
    },
  );
  test(
    'trends use counts not money or quantities and include directional wording',
    () {
      final yesterday = draft(value: 10000, date: DateTime(2026, 9, 15));
      final lower = WasteSummary(
        [draft(), yesterday, yesterday],
        WastePeriod.today,
        wasteTestNow,
      );
      expect(lower.trendValue, '↓ 50%');
      expect(lower.trendDetail, 'Fewer records than yesterday');
      final higher = WasteSummary(
        [draft(), draft(), yesterday],
        WastePeriod.today,
        wasteTestNow,
      );
      expect(higher.trendValue, '↑ 100%');
      expect(higher.trendDetail, 'More records than yesterday');
    },
  );
  test('UTC instants use local calendar boundaries and relative dates', () {
    final localMidnight = DateTime(2026, 9, 16);
    final summary = WasteSummary(
      [draft(date: localMidnight.toUtc())],
      WastePeriod.today,
      wasteTestNow,
    );
    expect(summary.count, 1);
    expect(wasteRelativeDate(localMidnight.toUtc(), wasteTestNow), 'Today');
    expect(
      wasteRelativeDate(DateTime(2026, 9, 15, 23), wasteTestNow),
      'Yesterday',
    );
    expect(wasteRelativeDate(DateTime(2026, 9, 1), wasteTestNow), '01/09/2026');
  });
  test('equal dates have deterministic document ordering', () {
    expect(
      newestWasteFirst([
        draft().copyWith(id: 'z'),
        draft().copyWith(id: 'a'),
      ]).map((r) => r.id),
      ['a', 'z'],
    );
  });
  test(
    'recent records sorted newest first and limited to five within period',
    () {
      final records = List.generate(
        8,
        (i) => draft(name: '$i', date: DateTime(2026, 9, 16, i)),
      );
      records.add(draft(name: 'outside', date: DateTime(2026, 10, 1)));
      final recent = WasteSummary(
        records,
        WastePeriod.today,
        wasteTestNow,
      ).recent;
      expect(recent.map((r) => r.itemName), ['7', '6', '5', '4', '3']);
    },
  );
}
