import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_strings.dart';
import 'core/providers/theme_mode_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/presentation/widgets/notification_popup_host.dart';
import 'features/notifications/presentation/widgets/notification_bell.dart';

class FreshTrackApp extends ConsumerWidget {
  const FreshTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) => NotificationPopupHost(
        onView: () => appRouter.go(AppRoutes.expiry),
        child: Stack(children: [child!, const NotificationSyncHost()]),
      ),
    );
  }
}
