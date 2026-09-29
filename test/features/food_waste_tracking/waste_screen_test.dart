import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/providers/food_waste_provider.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/screens/waste_tracker_screen.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/widgets/waste_summary_card.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/widgets/waste_period_selector.dart';
import 'support/waste_test_session.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/providers/pantry_waste_provider.dart';

void main() {
  late WasteTestSession session;
  setUp(() => session = WasteTestSession());
  tearDown(() => session.changes.close());

  Future<void> open(
    WidgetTester tester, {
    bool history = false,
    Size size = const Size(430, 1600),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foodWasteRepositoryProvider.overrideWithValue(session.repository),
          wastePantryServiceProvider.overrideWithValue(session.pantry),
          wasteAuthUidProvider.overrideWith((ref) => session.auth()),
          wasteClockProvider.overrideWithValue(() => wasteTestNow),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: WasteTrackerScreen(history: history),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        250,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await reveal(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> openForm(WidgetTester tester) async =>
      tap(tester, find.widgetWithText(FilledButton, 'Record Waste'));
  Future<void> fill(
    WidgetTester tester, {
    String name = 'Custom meal',
    String quantity = '2',
    String value = '150',
  }) async {
    await tester.enterText(find.byKey(const ValueKey('waste-name')), name);
    await tester.enterText(
      find.byKey(const ValueKey('waste-quantity')),
      quantity,
    );
    await tester.enterText(find.byKey(const ValueKey('waste-value')), value);
  }

  Future<void> menu(WidgetTester tester, String name, String action) async {
    await tap(tester, find.byTooltip('Actions for $name'));
    await tap(tester, find.text(action).last);
  }

  testWidgets(
    'compact balanced grid shows recent heading and first record on phone',
    (tester) async {
      session.seed('alice', 'id', draft());
      await open(tester, size: const Size(390, 844));
      final cards = find.byType(WasteSummaryCard);
      expect(cards, findsNWidgets(4));
      expect(
        tester.getSize(cards.at(0)).height,
        tester.getSize(cards.at(1)).height,
      );
      expect(
        tester.getSize(cards.at(2)).height,
        tester.getSize(cards.at(3)).height,
      );
      expect(tester.getSize(cards.at(0)).height, lessThan(140));
      expect(
        tester.getTopLeft(find.text('Recent Waste Records')).dy,
        lessThan(700),
      );
      expect(tester.getBottomLeft(find.text('Apples')).dy, lessThan(844));
      expect(find.text('No previous data'), findsOneWidget);
      expect(find.text('Record more waste to see trends'), findsOneWidget);
      final buttons = find.descendant(
        of: find.byType(WastePeriodSelector),
        matching: find.byType(TextButton),
      );
      expect(
        tester.getSize(buttons.at(0)).width,
        tester.getSize(buttons.at(1)).width,
      );
      expect(
        tester.getSize(buttons.at(1)).width,
        tester.getSize(buttons.at(2)).width,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'insight and all summary fields follow period; empty insight hidden',
    (tester) async {
      session.seed('alice', 'a', draft(unit: 'bottle', value: 1000));
      session.seed(
        'alice',
        'b',
        draft(quantity: 1.5, unit: 'kg', value: 450.5),
      );
      session.seed(
        'alice',
        'old',
        draft(
          name: 'Old',
          date: DateTime(2026, 9, 1),
          value: 5000,
        ).copyWith(reason: 'Spoiled'),
      );
      await open(tester);
      expect(find.text('2 units'), findsOneWidget);
      expect(find.text('2 bottle • 1.5 kg'), findsOneWidget);
      expect(find.text('Rs. 1,450.50'), findsOneWidget);
      expect(
        find.textContaining('Most common reason: Expired (2/2)'),
        findsOneWidget,
      );
      await tap(tester, find.text('This Month'));
      expect(find.text('3 units'), findsOneWidget);
      expect(find.text('Rs. 6,450.50'), findsOneWidget);
      expect(
        find.textContaining('Most common reason: Expired (2/3)'),
        findsOneWidget,
      );
      session.changeUser('bob');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('waste-insight')), findsNothing);
      expect(find.text('No waste recorded this month'), findsOneWidget);
      expect(find.text('Rs. 6,450.50'), findsNothing);
    },
  );
  testWidgets('duplicate Cancel keeps draft and Save Anyway writes once', (
    tester,
  ) async {
    session.seed('alice', 'id', draft());
    await open(tester);
    await openForm(tester);
    await fill(tester, name: '  APPLES ');
    await tap(tester, find.byKey(const ValueKey('save-waste')));
    expect(
      find.text('This waste record looks similar to one already saved.'),
      findsOneWidget,
    );
    expect(session.store.addCalls, 0);
    await tap(tester, find.text('Cancel'));
    expect(find.byKey(const ValueKey('waste-name')), findsOneWidget);
    expect(session.store.documents.length, 1);
    await tap(tester, find.byKey(const ValueKey('save-waste')));
    final saveAnyway = find.widgetWithText(FilledButton, 'Save Anyway');
    await tester.tap(saveAnyway);
    await tester.tap(saveAnyway, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(session.store.addCalls, 1);
    expect(session.store.documents.length, 2);
    expect(find.byKey(const ValueKey('waste-name')), findsNothing);
  });
  testWidgets(
    'account change during duplicate confirmation cannot save draft',
    (tester) async {
      session.seed('alice', 'id', draft());
      await open(tester);
      await openForm(tester);
      await fill(tester, name: 'Apples');
      await tap(tester, find.byKey(const ValueKey('save-waste')));
      session.changeUser('bob');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Save Anyway'));
      expect(session.store.addCalls, 0);
      expect(find.textContaining('Your account changed.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'large text, long values, many records and mixed units stay scrollable',
    (tester) async {
      final units = ['kg', 'pcs', 'bottle', 'pack', 'g', 'L'];
      for (var i = 0; i < 12; i++) {
        session.seed(
          'alice',
          '$i',
          draft(
            name: 'Long homemade vegetable rice dish number $i',
            unit: units[i % units.length],
            value: 123456789012.5,
          ),
        );
      }
      await open(tester, size: const Size(320, 700), scale: 2);
      expect(tester.takeException(), isNull);
      await reveal(tester, find.text('Recent Waste Records'));
      expect(tester.takeException(), isNull);
      await reveal(
        tester,
        find.text('Long homemade vegetable rice dish number 10'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty state, period selector and four summary cards', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Items Wasted'), findsOneWidget);
    expect(find.text('Quantity Logged'), findsOneWidget);
    expect(find.text('Estimated Value'), findsOneWidget);
    expect(find.text('Trend vs Previous Period'), findsOneWidget);
    expect(find.text('No change'), findsOneWidget);
    await reveal(tester, find.text('No waste recorded today'));
    expect(find.text('No waste recorded today'), findsOneWidget);
  });
  testWidgets(
    'create custom record, summary update and read after pull refresh',
    (tester) async {
      await open(tester);
      await openForm(tester);
      await fill(tester);
      await tap(tester, find.byKey(const ValueKey('save-waste')));
      expect(session.store.addCalls, 1);
      await reveal(tester, find.text('Custom meal'));
      expect(find.text('Custom meal'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 700));
      await tester.pumpAndSettle();
      expect(session.store.readCalls, greaterThan(1));
      expect(session.store.documents.length, 1);
    },
  );
  testWidgets(
    'form validates empty name, nonpositive quantity and negative value',
    (tester) async {
      await open(tester);
      await openForm(tester);
      await fill(tester, name: ' ', quantity: '0', value: '-1');
      await tap(tester, find.byKey(const ValueKey('save-waste')));
      expect(find.text('Enter an item name.'), findsOneWidget);
      expect(find.text('Enter a quantity greater than 0.'), findsOneWidget);
      expect(find.text('Enter a value of 0 or more.'), findsOneWidget);
      expect(session.store.addCalls, 0);
    },
  );
  testWidgets('double-tapping save creates only one record', (tester) async {
    await open(tester);
    await openForm(tester);
    await fill(tester);
    final gate = Completer<void>();
    session.store.addGate = gate.future;
    final save = find.byKey(const ValueKey('save-waste'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.tap(save);
    await tester.pump();
    expect(session.store.addCalls, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(session.store.documents.length, 1);
  });
  testWidgets('failed save retains draft and shows safe permission message', (
    tester,
  ) async {
    await open(tester);
    await openForm(tester);
    await fill(tester);
    session.store.addError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'private backend detail',
    );
    await tap(tester, find.byKey(const ValueKey('save-waste')));
    expect(
      find.text(
        'Permission denied for waste records. Please contact the team.',
      ),
      findsOneWidget,
    );
    expect(find.text('private backend detail'), findsNothing);
    expect(find.text('Custom meal'), findsOneWidget);
    expect(session.store.documents, isEmpty);
    session.store.addError = null;
    await tap(tester, find.byKey(const ValueKey('save-waste')));
    expect(session.store.documents.length, 1);
  });
  testWidgets(
    'history edit preserves document and delete requires confirmation',
    (tester) async {
      session.seed('alice', 'id', draft());
      await open(tester, history: true);
      await menu(tester, 'Apples', 'Edit');
      await fill(tester, name: 'Rice', quantity: '0.5');
      await tap(tester, find.byKey(const ValueKey('save-waste')));
      expect(session.store.addCalls, 0);
      expect(session.store.updateCalls, 1);
      expect(
        session.store.documents['users/alice/waste_records/id']!['itemName'],
        'Rice',
      );
      await menu(tester, 'Rice', 'Delete');
      expect(find.text('Delete waste record?'), findsOneWidget);
      await tap(tester, find.text('Cancel'));
      expect(session.store.commitCalls, 0);
      await menu(tester, 'Rice', 'Delete');
      await tap(tester, find.widgetWithText(FilledButton, 'Delete'));
      expect(session.store.documents, isEmpty);
      expect(find.text('No waste recorded yet'), findsOneWidget);
    },
  );
  testWidgets('period updates recent records; See all includes older history', (
    tester,
  ) async {
    session.seed('alice', 'today', draft(name: 'Today item'));
    session.seed(
      'alice',
      'week',
      draft(name: 'Week item', date: DateTime(2026, 9, 14)),
    );
    session.seed(
      'alice',
      'month',
      draft(name: 'Month item', date: DateTime(2026, 9, 1)),
    );
    await open(tester);
    expect(find.text('Week item'), findsNothing);
    await tap(tester, find.text('This Week'));
    expect(find.text('Week item'), findsOneWidget);
    expect(find.text('Month item'), findsNothing);
    await tap(tester, find.text('This Month'));
    expect(find.text('Month item'), findsOneWidget);
    await tap(tester, find.text('See all >'));
    expect(find.text('Waste History'), findsOneWidget);
    expect(find.text('Today item'), findsOneWidget);
    expect(find.text('Month item'), findsOneWidget);
  });
  testWidgets('failed refresh keeps records with friendly feedback', (
    tester,
  ) async {
    session.seed('alice', 'id', draft());
    await open(tester, history: true);
    session.store.readError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.text('Apples'), findsOneWidget);
    expect(
      find.text("Couldn't refresh. Showing current data."),
      findsOneWidget,
    );
  });
  testWidgets('logout hides existing records and an open form draft', (
    tester,
  ) async {
    session.seed('alice', 'id', draft());
    await open(tester);
    await openForm(tester);
    await fill(tester);
    session.changeUser(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('waste-name')), findsNothing);
    expect(find.textContaining('Your account changed.'), findsOneWidget);
    expect(session.store.addCalls, 0);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Sign in to view your waste records.'), findsOneWidget);
    expect(find.text('Apples'), findsNothing);
  });
  testWidgets('autocomplete, unit and reason selection and date picker work', (
    tester,
  ) async {
    await open(tester);
    await openForm(tester);
    await tester.enterText(find.byKey(const ValueKey('waste-name')), 'MI');
    await tester.pumpAndSettle();
    await tap(tester, find.text('Milk').last);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('waste-name')))
          .controller!
          .text,
      'Milk',
    );
    await tester.enterText(find.byKey(const ValueKey('waste-quantity')), '0.5');
    await tap(tester, find.byType(DropdownButtonFormField<String>).first);
    await tap(tester, find.text('kg').last);
    await tap(tester, find.text('Cooked Too Much').last);
    await tap(tester, find.text('Date: 16/09/2026'));
    await tap(tester, find.text('15').last);
    await tap(tester, find.text('OK'));
    await tap(tester, find.byKey(const ValueKey('save-waste')));
    final data = session.store.documents.values.single;
    expect(data['itemName'], 'Milk');
    expect(data['unit'], 'kg');
    expect(data['reason'], 'Cooked Too Much');
    expect((data['wastedAt'] as Timestamp).toDate().day, 15);
  });

  testWidgets(
    'failed edit and delete leave record intact and do not expose errors',
    (tester) async {
      session.seed('alice', 'id', draft());
      await open(tester, history: true);
      session.store.updateError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await menu(tester, 'Apples', 'Edit');
      await fill(tester, name: 'Rice');
      await tap(tester, find.byKey(const ValueKey('save-waste')));
      expect(
        find.text('Unable to save waste records. Please try again.'),
        findsOneWidget,
      );
      expect(session.store.documents.values.single['itemName'], 'Apples');
      await tester.pageBack();
      await tester.pumpAndSettle();
      session.store.deleteError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await menu(tester, 'Apples', 'Delete');
      await tap(tester, find.widgetWithText(FilledButton, 'Delete'));
      expect(find.text('Apples'), findsOneWidget);
      expect(session.store.documents.length, 1);
      expect(
        find.text('Unable to delete waste records. Please try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'account change during delete dialog cannot delete either account record',
    (tester) async {
      session.seed('alice', 'id', draft());
      session.seed('bob', 'id', draft(name: 'Bob meal'));
      await open(tester, history: true);
      await menu(tester, 'Apples', 'Delete');
      session.changeUser('bob');
      await tester.pumpAndSettle();
      await tap(tester, find.widgetWithText(FilledButton, 'Delete'));
      expect(session.store.commitCalls, 0);
      expect(session.store.documents.length, 2);
      expect(find.text('Bob meal'), findsOneWidget);
      expect(find.text('Apples'), findsNothing);
    },
  );

  testWidgets('narrow screen and large text do not overflow', (tester) async {
    session.seed(
      'alice',
      'id',
      draft(name: 'Long homemade vegetable rice dish'),
    );
    await open(tester, size: const Size(320, 700), scale: 2);
    expect(tester.takeException(), isNull);
    await openForm(tester);
    await fill(tester);
    expect(tester.takeException(), isNull);
  });
}
