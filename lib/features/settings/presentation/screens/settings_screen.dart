import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/providers/theme_mode_provider.dart';
import '../../../../core/router/app_routes.dart';
import '../../../shopping_list/presentation/providers/low_stock_suggestion_settings_provider.dart';
import '../widgets/settings_nav_card.dart';
import '../widgets/theme_option_button.dart';

final settingsUserEmailProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.email;
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final themeMode = ref.watch(themeModeProvider);
    final lowStockSettings = ref.watch(lowStockSuggestionSettingsProvider);
    final userNameAsync = ref.watch(currentUserNameProvider);

    final userName = userNameAsync.when(
      data: (name) => name.isNotEmpty ? name : AppStrings.userFallback,
      loading: () => AppStrings.userFallback,
      error: (_, _) => AppStrings.userFallback,
    );

    final email = ref.watch(settingsUserEmailProvider);

    final pageBackground = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: pageBackground,

      appBar: AppBar(
        title: Text(
          AppStrings.navSettings,
          style: textTheme.headlineMedium?.copyWith(
            fontSize: 20,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: pageBackground,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // PROFILE
            // ==================================================
            SettingsNavCard(
              icon: Icons.person_outline_rounded,
              title: AppStrings.profileTitle,
              subtitle: userName,
              detail: (email == null || email.isEmpty)
                  ? AppStrings.noEmailAvailable
                  : email,
              onTap: () {
                context.push(AppRoutes.profile);
              },
            ),

            const SizedBox(height: 12),

            // ==================================================
            // EXPIRY NOTIFICATIONS
            // ==================================================
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                context.push(AppRoutes.expiryNotifications);
              },
              child: const SettingsNavCard(
                icon: Icons.notifications_outlined,
                title: AppStrings.expiryNotificationsTitle,
                detail: AppStrings.expiryNotificationsSubtitle,
              ),
            ),

            const SizedBox(height: 28),

            Text(
              'Shopping preferences',
              style: textTheme.headlineMedium?.copyWith(
                fontSize: 18,
                color: colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 12),

            SettingsNavCard(
              icon: Icons.inventory_2_outlined,
              title: 'Low Stock Suggestions',
              detail: 'Control shopping suggestions and stock thresholds',
              trailingLabel: lowStockSettings.enabled ? 'On' : 'Off',
              onTap: () => context.push(AppRoutes.lowStockSuggestions),
            ),

            const SizedBox(height: 28),

            // ==================================================
            // THEME PREFERENCES
            // ==================================================
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
                // System
                Expanded(
                  child: ThemeOptionButton(
                    label: AppStrings.themeSystem,
                    icon: Icons.brightness_auto_outlined,
                    selected: themeMode == ThemeMode.system,
                    onPressed: () {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.system);
                    },
                  ),
                ),

                const SizedBox(width: 10),

                // Light
                Expanded(
                  child: ThemeOptionButton(
                    label: AppStrings.themeLight,
                    icon: Icons.light_mode_outlined,
                    selected: themeMode == ThemeMode.light,
                    onPressed: () {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.light);
                    },
                  ),
                ),

                const SizedBox(width: 10),

                // Dark
                Expanded(
                  child: ThemeOptionButton(
                    label: AppStrings.themeDark,
                    icon: Icons.dark_mode_outlined,
                    selected: themeMode == ThemeMode.dark,
                    onPressed: () {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.dark);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ==================================================
            // ACCOUNT
            // ==================================================
            Text(
              'Account',
              style: textTheme.headlineMedium?.copyWith(
                fontSize: 18,
                color: colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 12),

            // LOG OUT
            SettingsNavCard(
              icon: Icons.logout_rounded,
              title: 'Log Out',
              detail: 'Sign out of your PantryPal account',
              onTap: () => _showLogoutDialog(context),
            ),

            const SizedBox(height: 12),

            // DELETE ACCOUNT
            SettingsNavCard(
              icon: Icons.delete_outline_rounded,
              title: 'Delete Account',
              detail: 'Permanently delete your PantryPal account',
              onTap: () => _showDeleteAccountDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // LOGOUT
  // ================================================================

  Future<void> _showLogoutDialog(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log Out?'),
          content: const Text(
            'Are you sure you want to log out of PantryPal?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    try {
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      context.go(AppRoutes.login);
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Unable to log out. Please try again.',
          ),
        ),
      );
    }
  }

  // ================================================================
  // DELETE ACCOUNT
  // ================================================================

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Account?'),
          content: const Text(
            'This will permanently delete your PantryPal account. '
                'This action cannot be undone.\n\n'
                'Are you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      await user.delete();

      if (!context.mounted) return;

      context.go(AppRoutes.onboarding);
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;

      if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'For security, please log in again before deleting your account.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Unable to delete your account. Please try again.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong while deleting your account.',
          ),
        ),
      );
    }
  }
}