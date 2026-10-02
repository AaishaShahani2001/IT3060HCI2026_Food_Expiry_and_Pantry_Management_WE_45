import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_expiry_and_pantry_management/core/providers/current_user_provider.dart';
import 'package:food_expiry_and_pantry_management/core/theme/app_theme.dart';
import 'package:food_expiry_and_pantry_management/features/home/presentation/widgets/home_header.dart';

String _name = '';

class _Name extends CurrentUserNameNotifier {
  @override
  Future<String> build() async => _name;
}

String _headerText(WidgetTester tester) {
  final text = tester.widget<Text>(find.byType(Text).first);
  return text.textSpan!.toPlainText();
}

void main() {
  test('greeting follows the device local hour', () {
    expect(homeGreetingAt(DateTime(2026, 10, 1, 4, 59)), 'Good Night');
    expect(homeGreetingAt(DateTime(2026, 10, 1, 5)), 'Good Morning');
    expect(homeGreetingAt(DateTime(2026, 10, 1, 8, 30)), 'Good Morning');
    expect(homeGreetingAt(DateTime(2026, 10, 1, 11, 59)), 'Good Morning');
    expect(homeGreetingAt(DateTime(2026, 10, 1, 12)), 'Good Afternoon');
    expect(homeGreetingAt(DateTime(2026, 10, 1, 13, 20)), 'Good Afternoon');
    expect(homeGreetingAt(DateTime(2026, 10, 1, 16, 59)), 'Good Afternoon');
    expect(homeGreetingAt(DateTime(2026, 10, 1, 17)), 'Good Evening');
    expect(homeGreetingAt(DateTime(2026, 10, 1, 18, 45)), 'Good Evening');
    expect(homeGreetingAt(DateTime(2026, 10, 1, 20, 59)), 'Good Evening');
    expect(homeGreetingAt(DateTime(2026, 10, 1, 21)), 'Good Night');
    expect(homeGreetingAt(DateTime(2026, 10, 1, 22, 30)), 'Good Night');
  });

  Future<void> pumpHeader(
    WidgetTester tester, {
    required DateTime time,
    ThemeData? theme,
    Size size = const Size(390, 200),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [currentUserNameProvider.overrideWith(_Name.new)],
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(body: HomeHeader(clock: () => time)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('puts the greeting and profile name on one line', (tester) async {
    _name = 'Aaisha';
    await pumpHeader(tester, time: DateTime(2026, 10, 1, 18, 45));
    expect(_headerText(tester), 'Good Evening, Aaisha');
    expect(find.byTooltip('Notifications'), findsOneWidget);
  });

  testWidgets('omits the name when the profile has none', (tester) async {
    _name = '   ';
    await pumpHeader(
      tester,
      time: DateTime(2026, 10, 1, 8, 30),
      theme: AppTheme.dark,
    );
    expect(_headerText(tester), 'Good Morning');
    expect(tester.takeException(), isNull);
  });

  testWidgets('long names stay on one line without overflow', (tester) async {
    _name = 'Aaisha With A Very Long Profile Name';
    await pumpHeader(
      tester,
      time: DateTime(2026, 10, 1, 13, 20),
      size: const Size(320, 240),
      scale: 1.6,
    );
    expect(_headerText(tester), contains('Good Afternoon, '));
    expect(tester.takeException(), isNull);
  });
}
