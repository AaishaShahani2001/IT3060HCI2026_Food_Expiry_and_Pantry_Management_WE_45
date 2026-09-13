import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/providers/theme_mode_provider.dart';
import '../widgets/settings_nav_card.dart';
import '../widgets/theme_option_button.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final themeMode = ref.watch(themeModeProvider);
    final userNameAsync = ref.watch(currentUserNameProvider);

    final userName = userNameAsync.when(
      data: (name) => name.isNotEmpty ? name : AppStrings.userFallback,
      loading: () => AppStrings.userFallback,
      error: (_, _) => AppStrings.userFallback,
    );
    final email = FirebaseAuth.instance.currentUser?.email;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          AppStrings.navSettings,
          style: textTheme.headlineMedium?.copyWith(
            fontSize: 20,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // UI-only placeholder. Profile editing/navigation belongs
            // to another team member and is not wired from Settings.
            SettingsNavCard(
              icon: Icons.person_outline_rounded,
              title: AppStrings.profileTitle,
              subtitle: userName,
              detail: (email == null || email.isEmpty)
                  ? AppStrings.noEmailAvailable
                  : email,
            ),
            const SizedBox(height: 12),
            // UI-only placeholder. Expiry notification settings belong
            // to another team member and are not wired from Settings.
            const SettingsNavCard(
              icon: Icons.notifications_outlined,
              title: AppStrings.expiryNotificationsTitle,
              detail: AppStrings.expiryNotificationsSubtitle,
            ),
            const SizedBox(height: 28),
            Text(
              AppStrings.themePreferences,
              style: textTheme.headlineMedium?.copyWith(
                fontSize: 18,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ThemeOptionButton(
                    label: AppStrings.themeSystem,
                    icon: Icons.brightness_auto_outlined,
                    selected: themeMode == ThemeMode.system,
                    onPressed: () => ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(ThemeMode.system),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ThemeOptionButton(
                    label: AppStrings.themeLight,
                    icon: Icons.light_mode_outlined,
                    selected: themeMode == ThemeMode.light,
                    onPressed: () => ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(ThemeMode.light),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ThemeOptionButton(
                    label: AppStrings.themeDark,
                    icon: Icons.dark_mode_outlined,
                    selected: themeMode == ThemeMode.dark,
                    onPressed: () => ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(ThemeMode.dark),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
