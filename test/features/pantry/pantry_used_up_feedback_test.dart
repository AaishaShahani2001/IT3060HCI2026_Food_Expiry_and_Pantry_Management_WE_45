import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_colors.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_routes.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/data/services/pantry_firestore_service.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/domain/models/removed_pantry_item.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/utils/pantry_item_actions.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/utils/pantry_snackbar.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/widgets/pantry_item_card.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/widgets/pantry_items_sliver.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/models/shopping_item_draft.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_list_provider.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/screens/add_shopping_item_screen.dart';
import 'package:go_router/go_router.dart';

import '../shopping_list/support/fake_firestore.dart';

PantryItem basmati() {
  return PantryItem(
    id: 'rice',
    firestoreId: 'rice',
    name: 'Basmati Rice',
    category: PantryCategory.grains,
    location: PantryLocation.pantry,
    quantity: 2,
    originalQuantity: 5,
    unit: PantryUnit.kg,
    priceAmount: 800,
    priceType: PantryPriceType.totalPrice,
    expiryDate: DateTime(2026, 12, 1),
    photoUrl: 'https://example.com/rice.jpg',
    imagePublicId: 'pantry/rice',
    imageProvider: 'cloudinary',
  );
}

PantryItem eggs() {
  return PantryItem(
    id: 'eggs',
    firestoreId: 'eggs',
    name: 'Eggs',
    category: PantryCategory.dairy,
    location: PantryLocation.refrigerator,
    quantity: 12,
    unit: PantryUnit.items,
  );
}

class _MemoryPantry extends PantryItemsNotifier {
  _MemoryPantry(List<PantryItem> seed) : items = List.of(seed);

  final List<PantryItem> items;
  bool failUsedUp = false;
  bool failRestore = false;
  int usedUpCalls = 0;
  int restoreCalls = 0;
  double? quantityBeforeEdit;

  @override
  Stream<List<PantryItem>> build() => Stream.value(List.of(items));

  @override
  Future<RemovedPantryItem?> markAsUsedUp(
    PantryItem item, {
    required int originalIndex,
  }) async {
    usedUpCalls++;
    if (ref.read(pantryBusyItemIdsProvider).contains(item.id)) return null;
    final busy = ref.read(pantryBusyItemIdsProvider.notifier);
    busy.start(item.id);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (failUsedUp) {
        throw PantryFirestoreException(
          'Unable to mark ${item.name} as used up. Please try again.',
        );
      }
      final index = items.indexWhere((entry) => entry.id == item.id);
      if (index < 0) return null;
      final snapshot = items.removeAt(index);
      state = AsyncData(List.of(items));
      return RemovedPantryItem(item: snapshot, originalIndex: originalIndex);
    } finally {
      busy.stop(item.id);
    }
  }

  @override
  Future<void> restoreUsedUpItem(RemovedPantryItem removedItem) async {
    restoreCalls++;
    if (failRestore) {
      throw const PantryFirestoreException(
        'Unable to restore this item. Please try again.',
      );
    }
    final insertAt = removedItem.originalIndex.clamp(0, items.length);
    items.insert(insertAt, removedItem.item);
    state = AsyncData(List.of(items));
  }

  @override
  PantryQuantityChangeResult changeQuantityOptimistically({
    required PantryItem item,
    required double delta,
    void Function(PantryQuantityWriteResult result)? onFlushed,
  }) {
    final index = items.indexWhere((entry) => entry.id == item.id);
    if (index < 0) return PantryQuantityChangeResult.ignored;
    quantityBeforeEdit ??= items[index].quantity;
    final next = double.parse(
      (items[index].quantity + delta).toStringAsFixed(2),
    );
    if (next < 0) return PantryQuantityChangeResult.wouldGoNegative;
    items[index] = items[index].copyWith(quantity: next);
    state = AsyncData(List.of(items));
    onFlushed?.call(
      PantryQuantityWriteResult(
        itemId: item.id,
        itemName: item.name,
        quantityLabel: items[index].quantityLabel,
        success: true,
      ),
    );
    return PantryQuantityChangeResult.applied;
  }

  @override
  Future<void> undoQuantityChange(String itemId) async {
    final original = quantityBeforeEdit;
    if (original == null) return;
    final index = items.indexWhere((entry) => entry.id == itemId);
    if (index < 0) return;
    items[index] = items[index].copyWith(quantity: original);
    quantityBeforeEdit = null;
    state = AsyncData(List.of(items));
  }
}

class _PantryPage extends ConsumerStatefulWidget {
  const _PantryPage({this.disposeCaller = false, this.useCard = false});

  final bool disposeCaller;
  final bool useCard;

  @override
  ConsumerState<_PantryPage> createState() => _PantryPageState();
}

class _PantryPageState extends ConsumerState<_PantryPage> {
  final ScrollController scrollController = ScrollController();
  bool showCaller = true;

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(pantryItemsProvider).asData?.value ?? const [];
    final filters = ref.watch(pantryFilterProvider);
    final actions = showCaller && items.isNotEmpty && !widget.useCard
        ? Builder(
            builder: (itemContext) {
              final item = items.first;
              return Column(
                children: [
                  TextButton(
                    onPressed: () {
                      handlePantryUsedUp(
                        context: itemContext,
                        ref: ref,
                        item: item,
                        originalIndex: 0,
                      );
                      if (widget.disposeCaller) {
                        setState(() => showCaller = false);
                      }
                    },
                    child: const Text('Mark used up'),
                  ),
                  TextButton(
                    onPressed: () => handlePantryQuantityDelta(
                      context: itemContext,
                      ref: ref,
                      item: item,
                      delta: 1,
                    ),
                    child: const Text('Increase quantity'),
                  ),
                ],
              );
            },
          )
        : const SizedBox.shrink();

    return Scaffold(
      body: Column(
        children: [
          Text('location:${filters.selectedLocation?.name ?? 'none'}'),
          Text('query:${filters.searchQuery}'),
          actions,
          Expanded(
            child: widget.useCard
                ? CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      PantryItemsSliver(
                        items: items,
                        viewMode: PantryViewMode.cards,
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 1200)),
                    ],
                  )
                : ListView(
                    controller: scrollController,
                    children: [
                      for (final item in items)
                        Text(item.name, key: ValueKey(item.id)),
                      const SizedBox(height: 1200),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

void main() {
  test('draft keeps name, category and unit and leaves quantity empty', () {
    final draft = ShoppingItemDraft.fromPantryItem(basmati());
    expect(draft.name, 'Basmati Rice');
    expect(draft.category, 'Rice, Grains and Cereals');
    expect(draft.unit, PantryUnit.kg);
    expect(draft.quantity, isNull);

    final custom = ShoppingItemDraft.fromPantryItem(
      PantryItem(
        id: 'custom',
        firestoreId: 'custom',
        name: 'Mystery Grain',
        category: PantryCategory.grains,
        location: PantryLocation.pantry,
        quantity: 4,
        unit: PantryUnit.kg,
      ),
    );
    expect(custom.category, 'Rice, Grains and Cereals');
    expect(custom.quantity, isNull);
  });

  group('Used Up feedback', () {
    late ShoppingTestSession session;
    late _MemoryPantry pantry;
    late GoRouter router;
    var disposeCaller = false;
    var useCard = false;
    var routerReleased = false;

    setUp(() {
      session = ShoppingTestSession();
      pantry = _MemoryPantry([basmati()]);
      disposeCaller = false;
      useCard = false;
      routerReleased = false;
      router = GoRouter(
        initialLocation: '/pantry',
        routes: [
          GoRoute(
            path: '/pantry',
            builder: (_, _) =>
                _PantryPage(disposeCaller: disposeCaller, useCard: useCard),
          ),
          GoRoute(
            path: AppRoutes.addShoppingItem,
            builder: (context, state) {
              final extra = state.extra;
              return AddShoppingItemScreen(
                initialItem: extra is ShoppingItem ? extra : null,
                initialDraft: extra is ShoppingItemDraft ? extra : null,
              );
            },
          ),
        ],
      );
    });

    tearDown(() => session.changes.close());

    Future<void> pumpPantry(
      WidgetTester tester, {
      Size size = const Size(430, 900),
      double textScale = 1,
      bool dark = false,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() async {
        if (routerReleased) return;
        routerReleased = true;
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pantryItemsProvider.overrideWith(() => pantry),
            shoppingListRepositoryProvider.overrideWithValue(
              session.repository,
            ),
            shoppingAuthUidProvider.overrideWith((ref) => session.auth()),
          ],
          child: MaterialApp.router(
            theme: dark ? AppTheme.dark : AppTheme.light,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> markUsedUp(WidgetTester tester) async {
      await tester.tap(find.text('Mark used up'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 350));
    }

    Future<void> openAddForm(WidgetTester tester) async {
      await markUsedUp(tester);
      await tester.tap(find.byKey(PantryUsedUpSnackBarContent.addToListKey));
      await tester.pumpAndSettle();
    }

    Finder quantityField() {
      return find.byWidgetPredicate((widget) {
        return widget is TextField &&
            widget.decoration?.labelText == AppStrings.quantity;
      });
    }

    testWidgets('Used Up SnackBar dismisses after six seconds', (
      tester,
    ) async {
      await pumpPantry(tester);
      await markUsedUp(tester);

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.duration, const Duration(seconds: 6));
      expect(snackBar.persist, isFalse);
      expect(snackBar.action, isNull);
      expect(find.text('Basmati Rice marked as used up.'), findsOneWidget);
      expect(pantry.items, isEmpty);

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Basmati Rice marked as used up.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Basmati Rice marked as used up.'), findsNothing);
      expect(pantry.items, isEmpty);
      expect(pantry.restoreCalls, 0);
      expect(find.byType(AddShoppingItemScreen), findsNothing);
    });

    testWidgets('doing nothing keeps the item used up', (tester) async {
      await pumpPantry(tester);
      await markUsedUp(tester);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SnackBar), findsNothing);
      expect(pantry.items, isEmpty);
      expect(session.store.addCalls, 0);
    });

    testWidgets('Undo restores the snapshot and closes the SnackBar', (
      tester,
    ) async {
      pantry = _MemoryPantry([basmati(), eggs()]);
      await pumpPantry(tester);
      await markUsedUp(tester);

      expect(pantry.items.map((item) => item.name), ['Eggs']);
      await tester.tap(find.byKey(PantryUsedUpSnackBarContent.undoKey));
      await tester.tap(
        find.byKey(PantryUsedUpSnackBarContent.undoKey),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(pantry.restoreCalls, 1);
      expect(find.text('Basmati Rice marked as used up.'), findsNothing);
      expect(find.text('Basmati Rice restored.'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).action, isNull);
      expect(pantry.items.map((item) => item.id), ['rice', 'eggs']);
      final restored = pantry.items.first;
      expect(restored.quantity, 2);
      expect(restored.originalQuantity, 5);
      expect(restored.unit, PantryUnit.kg);
      expect(restored.category, PantryCategory.grains);
      expect(restored.location, PantryLocation.pantry);
      expect(restored.priceAmount, 800);
      expect(restored.expiryDate, DateTime(2026, 12, 1));
      expect(restored.photoUrl, 'https://example.com/rice.jpg');
      expect(restored.imagePublicId, 'pantry/rice');
      expect(restored.imageProvider, 'cloudinary');
      expect(session.store.documents, isEmpty);
    });

    testWidgets('Undo failure stays consistent and can retry', (tester) async {
      await pumpPantry(tester);
      await markUsedUp(tester);
      pantry.failRestore = true;

      await tester.tap(find.byKey(PantryUsedUpSnackBarContent.undoKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Unable to restore Basmati Rice. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('Firebase'), findsNothing);
      expect(pantry.items, isEmpty);
      expect(find.byType(AddShoppingItemScreen), findsNothing);

      pantry.failRestore = false;
      tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(pantry.restoreCalls, 2);
      expect(pantry.items.single.id, 'rice');
      expect(find.text('Basmati Rice restored.'), findsOneWidget);
    });

    testWidgets('Add to List opens the shopping form and keeps Used Up', (
      tester,
    ) async {
      await pumpPantry(tester);
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(_PantryPage)),
      );
      scope
          .read(pantryFilterProvider.notifier)
          .setLocation(PantryLocation.refrigerator);
      scope.read(pantryFilterProvider.notifier).setSearchQuery('rice');
      await tester.pump();
      final page = tester.state<_PantryPageState>(find.byType(_PantryPage));
      page.scrollController.jumpTo(240);
      await tester.pump();

      await openAddForm(tester);

      expect(find.byType(AddShoppingItemScreen), findsOneWidget);
      expect(router.state.uri.path, AppRoutes.addShoppingItem);
      expect(pantry.items, isEmpty);
      expect(pantry.restoreCalls, 0);
      expect(find.text('Basmati Rice'), findsWidgets);
      expect(find.text('Rice, Grains and Cereals'), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);
      expect(
        tester.widget<TextField>(quantityField()).controller?.text,
        isEmpty,
      );

      await tester.enterText(quantityField(), '3');
      expect(tester.widget<TextField>(quantityField()).controller?.text, '3');

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(AddShoppingItemScreen), findsNothing);
      expect(pantry.items, isEmpty);
      expect(session.store.addCalls, 0);
      expect(find.text('location:refrigerator'), findsOneWidget);
      expect(find.text('query:rice'), findsOneWidget);
      expect(page.scrollController.offset, 240);
    });

    testWidgets('confirming the shopping form saves one item', (tester) async {
      await pumpPantry(tester);
      await openAddForm(tester);
      await tester.enterText(quantityField(), '3');
      await tester.ensureVisible(find.text(AppStrings.addItem));
      await tester.tap(find.text(AppStrings.addItem));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Basmati Rice added to your Shopping List.'),
        findsOneWidget,
      );
      expect(pantry.items, isEmpty);
      expect(session.store.addCalls, 1);
      final saved = session.store.documents.values.single;
      expect(saved['name'], 'Basmati Rice');
      expect(saved['quantity'], 3);
      expect(saved['unit'], 'kg');
      expect(saved['category'], 'Rice, Grains and Cereals');
    });

    testWidgets('existing shopping duplicate handling still applies', (
      tester,
    ) async {
      session.store.seed('alice', 'rice', 'Basmati Rice');
      await pumpPantry(tester);
      await openAddForm(tester);
      await tester.enterText(quantityField(), '1');
      await tester.ensureVisible(find.text(AppStrings.addItem));
      await tester.tap(find.text(AppStrings.addItem));
      await tester.pumpAndSettle();

      expect(find.text('Already on your list'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AddShoppingItemScreen), findsOneWidget);
      expect(session.store.addCalls, 0);
      expect(session.store.documents, hasLength(1));
      expect(pantry.items, isEmpty);
      expect(
        find.text('Basmati Rice added to your Shopping List.'),
        findsNothing,
      );
    });

    testWidgets('a failed shopping save keeps the draft and pantry state', (
      tester,
    ) async {
      session.store.addError = Exception(
        'FirebaseException: permission-denied',
      );
      await pumpPantry(tester);
      await openAddForm(tester);
      await tester.enterText(quantityField(), '2');
      await tester.ensureVisible(find.text(AppStrings.addItem));
      await tester.tap(find.text(AppStrings.addItem));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Unable to complete this shopping action. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('FirebaseException'), findsNothing);
      expect(find.byType(AddShoppingItemScreen), findsOneWidget);
      expect(tester.widget<TextField>(quantityField()).controller?.text, '2');
      expect(find.text('Basmati Rice'), findsWidgets);
      expect(pantry.items, isEmpty);
      expect(
        find.text('Basmati Rice added to your Shopping List.'),
        findsNothing,
      );
    });

    testWidgets('Used Up failure does not open shopping or claim success', (
      tester,
    ) async {
      pantry.failUsedUp = true;
      await pumpPantry(tester);
      await markUsedUp(tester);

      expect(
        find.text('Unable to mark Basmati Rice as used up. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('marked as used up'), findsNothing);
      expect(find.byType(AddShoppingItemScreen), findsNothing);
      expect(router.state.uri.path, '/pantry');
      expect(pantry.items.single.name, 'Basmati Rice');
      expect(session.store.addCalls, 0);
    });

    testWidgets('SnackBars replace each other instead of stacking', (
      tester,
    ) async {
      await pumpPantry(tester);
      await tester.tap(find.text('Increase quantity'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.tap(find.text('Mark used up'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('quantity updated'), findsNothing);
      expect(find.text('Basmati Rice marked as used up.'), findsOneWidget);
    });

    testWidgets('removing the caller does not block the SnackBar', (
      tester,
    ) async {
      disposeCaller = true;
      await pumpPantry(tester);
      await markUsedUp(tester);

      expect(find.text('Mark used up'), findsNothing);
      expect(find.text('Basmati Rice marked as used up.'), findsOneWidget);
      expect(pantry.items, isEmpty);

      await tester.tap(find.byKey(PantryUsedUpSnackBarContent.addToListKey));
      await tester.pumpAndSettle();
      expect(find.byType(AddShoppingItemScreen), findsOneWidget);
      expect(pantry.items, isEmpty);
    });

    testWidgets('card actions still show feedback after the card is removed', (
      tester,
    ) async {
      useCard = true;
      await pumpPantry(tester);
      await tester.tap(find.byTooltip('Actions for Basmati Rice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Used Up'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(PantryItemCard), findsNothing);
      expect(find.text('Basmati Rice marked as used up.'), findsOneWidget);
      expect(snackBarOf(tester).persist, isFalse);
    });

    testWidgets('small text and themes keep the actions readable', (
      tester,
    ) async {
      await pumpPantry(tester, size: const Size(320, 640), textScale: 2);
      await markUsedUp(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('UNDO'), findsOneWidget);
      expect(find.text('ADD TO LIST'), findsOneWidget);
      expect(
        find.byTooltip('Add Basmati Rice to Shopping List'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.undo), findsOneWidget);
      expect(find.byIcon(Icons.add_shopping_cart_outlined), findsOneWidget);
      final addIcon = tester.widget<Icon>(
        find.byIcon(Icons.add_shopping_cart_outlined),
      );
      expect(addIcon.color, AppColors.primaryGreen);
      expect(addIcon.color, isNot(AppColors.statusRed));
      final message = tester.widget<Text>(
        find.text('Basmati Rice marked as used up.'),
      );
      expect(message.style?.color, isNotNull);
    });

    testWidgets('dark theme keeps Used Up actions readable', (tester) async {
      await pumpPantry(tester, dark: true);
      await markUsedUp(tester);
      expect(tester.takeException(), isNull);
      final darkAdd = tester.widget<Icon>(
        find.byIcon(Icons.add_shopping_cart_outlined),
      );
      final darkUndo = tester.widget<Icon>(find.byIcon(Icons.undo));
      expect(darkAdd.color, AppColors.darkGreen);
      expect(darkUndo.color, isNot(darkAdd.color));
      expect(darkAdd.color, isNot(AppColors.statusRed));
      final message = tester.widget<Text>(
        find.text('Basmati Rice marked as used up.'),
      );
      expect(message.style?.color, isNotNull);
    });

    testWidgets('quantity Undo still replaces itself and restores quantity', (
      tester,
    ) async {
      await pumpPantry(tester);
      await tester.tap(find.text('Increase quantity'));
      await tester.pump();
      await tester.tap(find.text('Increase quantity'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(SnackBar), findsOneWidget);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.duration, PantrySnackBar.quantityUndo);
      expect(snackBar.persist, isTrue);
      expect(snackBar.action?.label, 'UNDO');
      expect(pantry.items.single.quantity, 4);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('quantity updated'), findsOneWidget);

      await tester.tap(find.text('UNDO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(pantry.items.single.quantity, 2);
      expect(pantry.items.single.originalQuantity, 5);
      expect(find.text('Basmati Rice quantity restored.'), findsOneWidget);
      expect(find.text('UNDO'), findsNothing);
    });

    testWidgets('a normal shopping form stays empty without a draft', (
      tester,
    ) async {
      await pumpPantry(tester);
      router.go('/shopping/add?name=Oats');
      await tester.pumpAndSettle();

      expect(find.byType(AddShoppingItemScreen), findsOneWidget);
      expect(find.text('Oats'), findsWidgets);
      expect(
        tester.widget<TextField>(quantityField()).controller?.text,
        isEmpty,
      );

      router.go('/pantry');
      await tester.pumpAndSettle();
      router.push(AppRoutes.addShoppingItem);
      await tester.pumpAndSettle();
      expect(find.text('Oats'), findsNothing);
      expect(
        tester.widget<TextField>(quantityField()).controller?.text,
        isEmpty,
      );
    });
  });
}

SnackBar snackBarOf(WidgetTester tester) {
  return tester.widget<SnackBar>(find.byType(SnackBar));
}
