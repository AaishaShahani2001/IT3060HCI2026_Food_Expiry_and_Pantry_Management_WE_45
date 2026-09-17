import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/router/app_router.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/core/providers/current_user_provider.dart';
import 'package:food_expiry_and_pantry_management/features/home/presentation/home_screen.dart';
import 'package:food_expiry_and_pantry_management/features/home/presentation/widgets/home_waste_summary_card.dart';
import 'package:food_expiry_and_pantry_management/features/pantry/presentation/providers/pantry_providers.dart';
import 'package:food_expiry_and_pantry_management/features/expiry/presentation/providers/expiry_provider.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/providers/food_waste_provider.dart';
import 'package:food_expiry_and_pantry_management/features/food_waste_tracking/presentation/screens/waste_tracker_screen.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/data/shopping_list_repository.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/providers/shopping_list_provider.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/screens/shopping_list_screen.dart';
import 'package:food_expiry_and_pantry_management/features/shopping_list/presentation/screens/add_shopping_item_screen.dart';
import 'support/waste_test_session.dart';

class _TestUserName extends CurrentUserNameNotifier {
  @override
  Future<String> build() async => 'Test user';
}

void main() {
  testWidgets(
    'Shop opens Shopping List only; Home opens Waste Tracker and Back returns Home',
    (tester) async {
      final session = WasteTestSession();
      addTearDown(() async {
        // Unmount paused/offstage providers before closing their auth streams.
        await tester.pumpWidget(const SizedBox.shrink());
        appRouter.dispose();
        await session.changes.close();
      });
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      appRouter.go('/shopping');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserNameProvider.overrideWith(_TestUserName.new),
            pantrySummaryProvider.overrideWithValue((total: 0, lowStock: 0)),
            expirySummaryProvider.overrideWithValue((
              total: 0,
              expired: 0,
              expiringSoon: 0,
              fresh: 0,
              unknown: 0,
            )),
            foodWasteRepositoryProvider.overrideWithValue(session.repository),
            wasteAuthUidProvider.overrideWith((ref) => session.auth()),
            wasteClockProvider.overrideWithValue(() => wasteTestNow),
            shoppingListRepositoryProvider.overrideWithValue(
              ShoppingListRepository(
                firestore: session.store,
                currentUid: () => session.uid,
              ),
            ),
            shoppingAuthUidProvider.overrideWith((ref) => session.auth()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShoppingListScreen), findsOneWidget);
      final bottom = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(bottom.items.length, 6);
      expect(bottom.currentIndex, 3);
      expect(find.widgetWithText(ChoiceChip, 'Waste Tracker'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Shopping List'), findsNothing);
      appRouter.push('/shopping/add?name=Milk');
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is EditableText && widget.controller.text == 'Milk',
        ),
        findsOneWidget,
      );
      expect(find.byType(AddShoppingItemScreen), findsOneWidget);
      appRouter.pop();
      await tester.pumpAndSettle();
      appRouter.go('/home');
      await tester.pumpAndSettle();
      final card = find.byType(HomeWasteSummaryCard);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      final reads = session.store.readCalls;
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(WasteTrackerScreen), findsOneWidget);
      expect(find.byType(ShoppingListScreen), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
      expect(session.store.readCalls, reads);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(HomeWasteSummaryCard), findsOneWidget);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .items
            .length,
        6,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
