import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/expiry_repository.dart';
import '../providers/expiry_provider.dart';

class EditExpiryTrackingScreen extends ConsumerStatefulWidget {
  const EditExpiryTrackingScreen({super.key, required this.alert});

  final ExpiryAlert alert;

  @override
  ConsumerState<EditExpiryTrackingScreen> createState() =>
      _EditExpiryTrackingScreenState();
}

class _EditExpiryTrackingScreenState
    extends ConsumerState<EditExpiryTrackingScreen> {
  late DateTime _expiryDate;
  late int _reminderDays;
  late bool _notificationEnabled;

  @override
  void initState() {
    super.initState();
    _expiryDate = widget.alert.expiryDate;
    _reminderDays = widget.alert.reminderDays;
    _notificationEnabled = widget.alert.notificationEnabled;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _saveChanges() async {
    final updatedAlert = widget.alert.copyWith(
      expiryDate: _expiryDate,
      daysUntilExpiry: _expiryDate.difference(DateTime.now()).inDays,
      reminderDays: _reminderDays,
      notificationEnabled: _notificationEnabled,
      message: '${widget.alert.itemName} expiry reminder',
    );

    await ref.read(saveExpiryAlertProvider)(updatedAlert);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Update ${widget.alert.itemName}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Expiry date'),
                subtitle: Text(
                  '${_expiryDate.day}/${_expiryDate.month}/${_expiryDate.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
                initialValue: _reminderDays,
                decoration: const InputDecoration(
                  labelText: 'Reminder days',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 day before')),
                  DropdownMenuItem(value: 2, child: Text('2 days before')),
                  DropdownMenuItem(value: 3, child: Text('3 days before')),
                  DropdownMenuItem(value: 5, child: Text('5 days before')),
                  DropdownMenuItem(value: 7, child: Text('7 days before')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _reminderDays = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notifications enabled'),
                value: _notificationEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationEnabled = value;
                  });
                },
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveChanges,
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
