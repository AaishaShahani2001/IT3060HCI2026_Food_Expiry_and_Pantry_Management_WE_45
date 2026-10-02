import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_colors.dart';
import 'package:food_expiry_and_pantry_management/core/constants/app_strings.dart';
import 'package:food_expiry_and_pantry_management/core/providers/current_user_provider.dart';

/// Greeting for the device's local hour.
///
/// 05:00–11:59 morning, 12:00–16:59 afternoon, 17:00–20:59 evening,
/// and 21:00–04:59 night.
String homeGreetingAt(DateTime time) {
  final hour = time.hour;
  if (hour >= 5 && hour < 12) return AppStrings.goodMorning;
  if (hour >= 12 && hour < 17) return AppStrings.goodAfternoon;
  if (hour >= 17 && hour < 21) return AppStrings.goodEvening;
  return AppStrings.goodNight;
}

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key, this.clock});

  /// Defaults to the device clock. Tests can supply a fixed time.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final userNameAsync = ref.watch(currentUserNameProvider);
    final userName = userNameAsync.maybeWhen(
      data: (name) => name.trim(),
      orElse: () => '',
    );
    final greeting = homeGreetingAt((clock ?? DateTime.now)());
    final line = userName.isEmpty ? greeting : '$greeting, $userName';

    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: userName.isEmpty ? greeting : '$greeting, ',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 20,
                    height: 1.2,
                  ),
                ),
                if (userName.isNotEmpty)
                  TextSpan(
                    text: userName,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      height: 1.2,
                    ),
                  ),
              ],
            ),
            key: ValueKey(line),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.search, color: colorScheme.onSurface),
          tooltip: AppStrings.searchTooltip,
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.notifications_outlined,
                color: colorScheme.onSurface,
              ),
              tooltip: AppStrings.notificationsTooltip,
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.unreadBadge,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
