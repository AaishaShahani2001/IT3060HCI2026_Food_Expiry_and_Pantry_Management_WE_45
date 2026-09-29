import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/data/local/pantry_food_catalog.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_food_suggestion.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/widgets/pantry_item_form.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pantry food catalogue', () {
    test('uses existing categories and unique names', () {
      expect(pantryFoodCatalog, hasLength(81));
      final names = pantryFoodCatalog.map(
        (item) => normalizeFoodName(item.name),
      );
      expect(names.toSet(), hasLength(pantryFoodCatalog.length));
      for (final item in pantryFoodCatalog) {
        expect(PantryCategory.values, contains(item.category));
      }
    });

    test('maps seafood and frozen foods onto existing categories', () {
      expect(exactPantryFoodMatch('Fish')?.category, PantryCategory.meat);
      expect(exactPantryFoodMatch('Prawns')?.category, PantryCategory.meat);
      expect(
        exactPantryFoodMatch('Frozen Vegetables')?.category,
        PantryCategory.vegetables,
      );
      expect(
        exactPantryFoodMatch('Frozen Chicken')?.category,
        PantryCategory.meat,
      );
      expect(exactPantryFoodMatch('Ice Cream')?.category, PantryCategory.dairy);
      expect(
        exactPantryFoodMatch('Ice Cream')?.suggestedLocation,
        PantryLocation.freezer,
      );
      expect(
        exactPantryFoodMatch('Frozen Pizza')?.category,
        PantryCategory.snacks,
      );
    });

    test('exact match ignores case and surrounding spaces', () {
      expect(exactPantryFoodMatch(' milk ')?.category, PantryCategory.dairy);
      expect(exactPantryFoodMatch('APPLE')?.category, PantryCategory.fruits);
      expect(exactPantryFoodMatch('Chicken')?.category, PantryCategory.meat);
      expect(exactPantryFoodMatch('Cheese')?.category, PantryCategory.dairy);
      expect(exactPantryFoodMatch('Rice')?.category, PantryCategory.grains);
      expect(exactPantryFoodMatch('Milk')?.defaultUnit, PantryUnit.liters);
    });

    test('partial and unknown names do not invent a category', () {
      expect(exactPantryFoodMatch('ch'), isNull);
      expect(exactPantryFoodMatch('mi'), isNull);
      expect(exactPantryFoodMatch('Homemade Curry'), isNull);
      expect(exactPantryFoodMatch('   '), isNull);
    });

    test('ranks prefix matches before keyword and contains matches', () {
      expect(
        matchPantryFoodSuggestions(
          'mi',
        ).map((item) => item.name).take(3).toList(),
        ['Milk', 'Milk Powder', 'Millet'],
      );
      expect(
        matchPantryFoodSuggestions('yog').map((item) => item.name).toList(),
        ['Yogurt'],
      );
      final chick = matchPantryFoodSuggestions(
        'chick',
      ).map((item) => item.name).toList();
      expect(chick.take(2).toList(), ['Chicken', 'Chickpeas']);

      final milk = matchPantryFoodSuggestions(
        'milk',
      ).map((item) => item.name).toList();
      expect(milk.first, 'Milk');
      expect(milk.indexOf('Milk'), lessThan(milk.indexOf('Milk Powder')));

      expect(matchPantryFoodSuggestions('yoghurt').single.name, 'Yogurt');
      expect(matchPantryFoodSuggestions('soda').single.name, 'Soft Drink');
      expect(matchPantryFoodSuggestions('  MIL ').first.name, 'Milk');
      expect(matchPantryFoodSuggestions('   '), isEmpty);
    });

    test('shows at most six suggestions', () {
      expect(matchPantryFoodSuggestions('a'), hasLength(6));
      expect(matchPantryFoodSuggestions('e'), hasLength(6));
      expect(matchPantryFoodSuggestions('ch').length, lessThanOrEqualTo(6));
    });

    test('merges loaded pantry names without duplicating catalogue items', () {
      final existing = [
        _item('1', 'Coconut Sambol', PantryCategory.other),
        _item('2', 'coconut sambol', PantryCategory.snacks),
        _item('3', 'milk', PantryCategory.beverages),
      ];

      final coco = matchPantryFoodSuggestions(
        'coco',
        existingItems: existing,
      ).map((item) => item.name).toList();
      expect(coco, contains('Coconut Milk'));
      expect(coco, contains('Coconut Water'));
      expect(coco, contains('Coconut Sambol'));
      expect(
        coco.where((name) => normalizeFoodName(name) == 'coconut sambol'),
        hasLength(1),
      );

      final milk = matchPantryFoodSuggestions('milk', existingItems: existing);
      expect(
        milk.where((item) => normalizeFoodName(item.name) == 'milk'),
        hasLength(1),
      );
      expect(milk.first.name, 'Milk');
      expect(milk.first.category, PantryCategory.dairy);
    });
  });

  group('PantryItemForm suggestions', () {
    testWidgets('selecting Milk fills the name and Dairy category', (
      tester,
    ) async {
      final log = _SubmitLog();
      await _pumpForm(tester, log: log);

      await tester.enterText(find.byType(TextFormField).first, 'mi');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('pantry-suggestion-Milk')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pantry-suggestion-Milk Powder')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pantry-suggestion-Millet')),
        findsOneWidget,
      );
      expect(log.count, 0);

      await tester.tap(find.byKey(const ValueKey('pantry-suggestion-Milk')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('pantry-suggestion-Milk')),
        findsNothing,
      );
      expect(_nameText(tester), 'Milk');
      expect(_category(tester), PantryCategory.dairy);
      expect(find.text('Category suggested from item name'), findsOneWidget);
      expect(log.count, 0);
      expect(find.text('Add Photo'), findsOneWidget);
    });

    testWidgets('an exact name selects its category and a prefix does not', (
      tester,
    ) async {
      await _pumpForm(tester, log: _SubmitLog());

      await tester.enterText(find.byType(TextFormField).first, 'ch');
      await tester.pumpAndSettle();
      expect(_category(tester), isNull);
      expect(find.text('Category suggested from item name'), findsNothing);
      expect(find.text('Select category'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, ' apple ');
      await tester.pumpAndSettle();
      expect(_category(tester), PantryCategory.fruits);
      expect(find.text('Category suggested from item name'), findsOneWidget);
    });

    testWidgets(
      'a manual category is kept until another suggestion is chosen',
      (tester) async {
        await _pumpForm(tester, log: _SubmitLog());

        await tester.enterText(find.byType(TextFormField).first, 'Milk');
        await tester.pumpAndSettle();
        expect(_category(tester), PantryCategory.dairy);

        await tester.tap(find.text('Item Photo (Optional)'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<PantryCategory>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Other').last);
        await tester.pumpAndSettle();

        expect(_category(tester), PantryCategory.other);
        expect(find.text('Category suggested from item name'), findsNothing);

        await tester.enterText(find.byType(TextFormField).first, 'MILK');
        await tester.pumpAndSettle();
        expect(_category(tester), PantryCategory.other);

        await tester.enterText(find.byType(TextFormField).first, 'yog');
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('pantry-suggestion-Yogurt')),
        );
        await tester.pumpAndSettle();

        expect(_nameText(tester), 'Yogurt');
        expect(_category(tester), PantryCategory.dairy);
        expect(find.text('Category suggested from item name'), findsOneWidget);
      },
    );

    testWidgets(
      'an unknown name can be saved only after a category is chosen',
      (tester) async {
        final log = _SubmitLog();
        await _pumpForm(tester, log: log);

        await tester.enterText(
          find.byType(TextFormField).at(0),
          '  Homemade Curry  ',
        );
        await tester.enterText(find.byType(TextFormField).at(1), '2');
        await tester.enterText(find.byType(TextFormField).at(2), '150');
        await tester.tap(find.text('Save item'));
        await tester.pumpAndSettle();

        expect(find.text('Category is required.'), findsOneWidget);
        expect(log.count, 0);
        expect(_category(tester), isNull);

        await tester.tap(find.byType(DropdownButtonFormField<PantryCategory>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Other').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save item'));
        await tester.pumpAndSettle();

        expect(log.count, 1);
        expect(log.data?.name, 'Homemade Curry');
        expect(log.data?.category, PantryCategory.other);
        expect(log.data?.quantity, 2);
      },
    );

    testWidgets('edit mode keeps the saved category until the name changes', (
      tester,
    ) async {
      await _pumpForm(
        tester,
        log: _SubmitLog(),
        initialItem: _item('milk-1', 'Milk', PantryCategory.dairy),
      );

      expect(find.text('Update item'), findsOneWidget);
      expect(_category(tester), PantryCategory.dairy);
      expect(find.text('Category suggested from item name'), findsNothing);
      expect(
        find.byKey(const ValueKey('pantry-suggestion-Milk')),
        findsNothing,
      );

      await tester.tap(find.byType(TextFormField).first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pantry-suggestion-Milk')),
        findsNothing,
      );

      await tester.enterText(find.byType(TextFormField).first, 'Apple');
      await tester.pumpAndSettle();
      expect(_category(tester), PantryCategory.fruits);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('loaded pantry names appear without another query', (
      tester,
    ) async {
      await _pumpForm(
        tester,
        log: _SubmitLog(),
        existingItems: [
          _item('sambol', 'Coconut Sambol', PantryCategory.other),
        ],
      );

      await tester.enterText(find.byType(TextFormField).first, 'coco');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('pantry-suggestion-Coconut Sambol')),
        findsOneWidget,
      );
      expect(find.text('Other'), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey('pantry-suggestion-Coconut Sambol')),
      );
      await tester.pumpAndSettle();
      expect(_nameText(tester), 'Coconut Sambol');
      expect(_category(tester), PantryCategory.other);
    });

    testWidgets('shows at most six suggestion rows', (tester) async {
      await _pumpForm(tester, log: _SubmitLog());
      await tester.enterText(find.byType(TextFormField).first, 'a');
      await tester.pumpAndSettle();

      final tiles = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'pantry-suggestion-',
            ),
      );
      expect(tiles, findsNWidgets(6));
    });

    testWidgets('tapping outside and pressing back close the panel', (
      tester,
    ) async {
      await _pumpForm(tester, log: _SubmitLog());
      await tester.enterText(find.byType(TextFormField).first, 'mi');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pantry-suggestion-Milk')),
        findsOneWidget,
      );

      await tester.tap(find.text('Item Photo (Optional)'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pantry-suggestion-Milk')),
        findsNothing,
      );

      await tester.enterText(find.byType(TextFormField).first, 'mi');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pantry-suggestion-Milk')),
        findsOneWidget,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(PantryItemForm), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pantry-suggestion-Milk')),
        findsNothing,
      );
    });

    testWidgets('stays readable in dark mode and on a small screen', (
      tester,
    ) async {
      await _pumpForm(
        tester,
        log: _SubmitLog(),
        theme: ThemeData.dark(useMaterial3: true),
        size: const Size(320, 700),
        textScale: 1.4,
      );

      await tester.enterText(find.byType(TextFormField).first, 'mi');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('pantry-suggestion-Milk')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('pantry-suggestion-Milk')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, isNot(Colors.white));
      expect(
        ThemeData.estimateBrightnessForColor(material.color!),
        Brightness.dark,
      );
    });
  });
}

PantryItem _item(String id, String name, PantryCategory category) {
  return PantryItem(
    id: id,
    firestoreId: id,
    name: name,
    category: category,
    location: PantryLocation.pantry,
    quantity: 1,
    unit: PantryUnit.items,
    price: 10,
  );
}

class _SubmitLog {
  PantryItemFormData? data;
  int count = 0;
}

Future<void> _pumpForm(
  WidgetTester tester, {
  required _SubmitLog log,
  PantryItem? initialItem,
  List<PantryItem> existingItems = const [],
  ThemeData? theme,
  Size size = const Size(400, 1600),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? ThemeData.light(useMaterial3: true),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        );
      },
      home: Scaffold(
        body: SingleChildScrollView(
          child: PantryItemForm(
            initialItem: initialItem,
            existingItems: existingItems,
            onSubmit: (data) async {
              log
                ..data = data
                ..count += 1;
            },
          ),
        ),
      ),
    ),
  );
}

String _nameText(WidgetTester tester) {
  return tester
      .widget<TextFormField>(find.byType(TextFormField).first)
      .controller!
      .text;
}

PantryCategory? _category(WidgetTester tester) {
  return tester
      .state<FormFieldState<PantryCategory>>(
        find.byType(DropdownButtonFormField<PantryCategory>),
      )
      .value;
}
