import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../pantry/presentation/providers/pantry_providers.dart';
import '../../domain/repositories/expiry_repository.dart';
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
    final result = await showDatePicker(
      context: context,

      firstDate: DateTime.now(),

      lastDate: DateTime.now().add(const Duration(days: 3650)),

      initialDate: DateTime.now().add(const Duration(days: 3)),
    );

    if (result != null) {
      setState(() {
        expiryDate = result;
      });
    }
  }

  Future<void> save() async {
    if (selectedItemId == null || expiryDate == null) {
      return;
    }

    final items = ref
        .read(pantryItemsProvider)
        .maybeWhen(data: (data) => data, orElse: () => []);

    final item = items.firstWhere((e) => e.id == selectedItemId);

    final alert = ExpiryAlert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),

      userId: "",

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

    await ref.read(saveExpiryAlertProvider)(alert);

    if (mounted) {
      Navigator.pop(context);
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
          return Padding(
            padding: const EdgeInsets.all(20),

            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "Select Pantry Item",

                    border: OutlineInputBorder(),
                  ),

                  items: items
                      .where((e) => e.expiryDate == null)
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
