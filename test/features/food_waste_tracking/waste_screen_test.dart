import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/providers/food_waste_provider.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/screens/waste_tracker_screen.dart';
import 'support/waste_test_session.dart';

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

  testWidgets('empty state, period selector and four summary cards', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Items Wasted'), findsOneWidget);
    expect(find.text('Quantity Logged'), findsOneWidget);
    expect(find.text('Estimated Value'), findsOneWidget);
    expect(find.text('Trend vs Previous Period'), findsOneWidget);
    expect(find.text('No previous data'), findsOneWidget);
    await reveal(tester, find.text('No waste recorded yet'));
    expect(find.text('No waste recorded yet'), findsOneWidget);
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
      find.textContaining('Showing your current waste records.'),
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
    await tap(tester, find.byType(DropdownButtonFormField<String>).last);
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
