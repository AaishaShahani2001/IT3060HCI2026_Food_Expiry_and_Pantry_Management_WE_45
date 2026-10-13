import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shopping_list/presentation/providers/low_stock_suggestion_settings_provider.dart';
import '../widgets/low_stock_suggestion_settings_card.dart';

class LowStockSuggestionSettingsScreen extends ConsumerWidget {
  const LowStockSuggestionSettingsScreen({super.key});

  Future<void> _resetToDefaults(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset low-stock settings?'),
        content: const Text(
          'This will restore the default suggestion levels for all categories.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref
        .read(lowStockSuggestionSettingsProvider.notifier)
        .resetThresholds();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Low-stock suggestion levels reset to defaults.'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(lowStockSuggestionSettingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back to Settings',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text(
          'Low Stock Suggestions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LowStockSuggestionSettingsCard(
                settings: settings,
                onEnabledChanged: (enabled) => ref
                    .read(lowStockSuggestionSettingsProvider.notifier)
                    .setEnabled(enabled),
                onThresholdChanged: (category, threshold) => ref
                    .read(lowStockSuggestionSettingsProvider.notifier)
                    .setThreshold(category, threshold),
              ),
              const SizedBox(height: 26),
              OutlinedButton.icon(
                onPressed: () => _resetToDefaults(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset to Defaults'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
