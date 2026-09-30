import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../pantry/presentation/providers/pantry_providers.dart';
import '../../domain/repositories/expiry_repository.dart';
import '../../domain/services/expiry_notification_provider.dart';
import '../providers/expiry_provider.dart';

class AddExpiryTrackingScreen extends ConsumerStatefulWidget {
  const AddExpiryTrackingScreen({super.key});

  @override
  ConsumerState<AddExpiryTrackingScreen> createState() =>
      _AddExpiryTrackingScreenState();
}

class _AddExpiryTrackingScreenState
    extends ConsumerState<AddExpiryTrackingScreen> {
  DateTime? expiryDate;

  String? selectedItemId;

  Future<void> pickDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
      initialDate: expiryDate ?? now.add(const Duration(days: 3)),
    );

    if (result != null) {
      setState(() {
        expiryDate = result;
      });
    }
  }

  Future<void> save() async {
    if (selectedItemId == null || expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a pantry item and an expiry date."),
        ),
      );
      return;
    }

    final items = ref
        .read(pantryItemsProvider)
        .maybeWhen(data: (data) => data, orElse: () => []);

    final itemIndex = items.indexWhere((e) => e.id == selectedItemId);
    if (itemIndex == -1) return;

    final item = items[itemIndex];
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? "";

    // 1. Update the item's expiry date in the pantry provider
    final updatedItem = item.copyWith(expiryDate: expiryDate);
    await ref.read(pantryItemsProvider.notifier).updateItem(updatedItem);

    // 2. Save the expiry alert in repository
    if (userId.isNotEmpty) {
      final alert = ExpiryAlert(
        id: item.id,
        userId: userId,
        itemId: item.id,
        itemName: item.name,
        expiryDate: expiryDate!,
        daysUntilExpiry: expiryDate!.difference(DateTime.now()).inDays,
        status: "active",
        priority: "medium",
        message: "${item.name} expiry reminder",
        isRead: false,
        createdAt: DateTime.now(),
      );

      try {
        await ref.read(saveExpiryAlertProvider)(alert);
      } catch (e) {
        debugPrint('Error saving alert: $e');
      }
    }

    final dateStr =
        "${expiryDate!.day}/${expiryDate!.month}/${expiryDate!.year}";
    await ref
        .read(expiryNotificationServiceProvider)
        .showExpiryNotification(
          title: "Expiry Tracking Saved",
          body: "Tracking enabled for ${item.name} (Expires: $dateStr)",
        );

    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pantry = ref.watch(pantryItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Track Item Expiry")),

      body: pantry.when(
        loading: () => const Center(child: CircularProgressIndicator()),

        error: (e, _) => Center(child: Text(e.toString())),

        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text(
                "No pantry items available.\nAdd items in your pantry first.",
                textAlign: TextAlign.center,
              ),
            );
          }

          final unTrackedItems = items
              .where((e) => e.expiryDate == null)
              .toList();
          final dropdownList = unTrackedItems.isNotEmpty
              ? unTrackedItems
              : items;

          return Padding(
            padding: const EdgeInsets.all(20),

            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedItemId,
                  decoration: const InputDecoration(
                    labelText: "Select Pantry Item",
                    border: OutlineInputBorder(),
                  ),

                  items: dropdownList
                      .map(
                        (e) =>
                            DropdownMenuItem(value: e.id, child: Text(e.name)),
                      )
                      .toList(),

                  onChanged: (value) {
                    setState(() {
                      selectedItemId = value;
                    });
                  },
                ),

                const SizedBox(height: 20),

                ListTile(
                  title: Text(
                    expiryDate == null
                        ? "Select Expiry Date"
                        : "${expiryDate!.day}/"
                              "${expiryDate!.month}/"
                              "${expiryDate!.year}",
                  ),

                  trailing: const Icon(Icons.calendar_month),

                  onTap: pickDate,
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,

                  child: ElevatedButton(
                    onPressed: save,

                    child: const Text("Save Tracking"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
