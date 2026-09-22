import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExpiryNotificationSettingsScreen extends StatefulWidget {
  const ExpiryNotificationSettingsScreen({super.key});

  @override
  State<ExpiryNotificationSettingsScreen> createState() =>
      _ExpiryNotificationSettingsScreenState();
}

class _ExpiryNotificationSettingsScreenState
    extends State<ExpiryNotificationSettingsScreen> {
  bool _notificationsEnabled = true;

  bool _expiringSoonEnabled = true;
  bool _expiredItemsEnabled = true;
  bool _useFirstEnabled = true;

  int _daysBefore = 3;

  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);

  String _frequency = 'Daily';

  Future<void> _selectTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
    );

    if (selectedTime == null) return;

    setState(() {
      _notificationTime = selectedTime;
    });
  }

  void _saveChanges() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expiry notification settings saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text(
          'Expiry Notifications',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NotificationMasterCard(
                enabled: _notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                },
              ),

              const SizedBox(height: 26),

              const _SectionTitle(title: 'Notify me for'),

              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: Column(
                  children: [
                    _NotificationOption(
                      title: 'Expiring soon',
                      subtitle: 'e.g. 1–3 days before expiry',
                      value: _expiringSoonEnabled,
                      enabled: _notificationsEnabled,
                      icon: Icons.schedule_rounded,
                      onChanged: (value) {
                        setState(() {
                          _expiringSoonEnabled = value;
                        });
                      },
                    ),
                    _NotificationOption(
                      title: 'Expired items',
                      subtitle: 'On the day the item expires',
                      value: _expiredItemsEnabled,
                      enabled: _notificationsEnabled,
                      icon: Icons.error_outline_rounded,
                      onChanged: (value) {
                        setState(() {
                          _expiredItemsEnabled = value;
                        });
                      },
                    ),
                    _NotificationOption(
                      title: '"Use First" reminders',
                      subtitle: 'Items that should be used earlier',
                      value: _useFirstEnabled,
                      enabled: _notificationsEnabled,
                      icon: Icons.priority_high_rounded,
                      onChanged: (value) {
                        setState(() {
                          _useFirstEnabled = value;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              const _SectionTitle(title: 'When to notify (days before expiry)'),

              const SizedBox(height: 10),

              _DropdownContainer<int>(
                value: _daysBefore,
                enabled: _notificationsEnabled,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 day before')),
                  DropdownMenuItem(value: 2, child: Text('2 days before')),
                  DropdownMenuItem(value: 3, child: Text('3 days before')),
                  DropdownMenuItem(value: 5, child: Text('5 days before')),
                  DropdownMenuItem(value: 7, child: Text('7 days before')),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _daysBefore = value;
                  });
                },
              ),

              const SizedBox(height: 22),

              const _SectionTitle(title: 'Notification time'),

              const SizedBox(height: 10),

              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _notificationsEnabled ? _selectTime : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        color: colorScheme.onSurface,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _notificationTime.format(context),
                          style: TextStyle(
                            color: _notificationsEnabled
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              const _SectionTitle(title: 'Notification frequency'),

              const SizedBox(height: 10),

              _DropdownContainer<String>(
                value: _frequency,
                enabled: _notificationsEnabled,
                items: const [
                  DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                  DropdownMenuItem(
                    value: 'Every 2 days',
                    child: Text('Every 2 days'),
                  ),
                  DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _frequency = value;
                  });
                },
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text(
                    'Save Changes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationMasterCard extends StatelessWidget {
  const _NotificationMasterCard({
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable Expiry Notifications',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Get notified about expiring and expired items',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _NotificationOption extends StatelessWidget {
  const _NotificationOption({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.icon,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final IconData icon;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CheckboxListTile(
      value: value,
      enabled: enabled,
      onChanged: (checked) {
        if (checked == null) return;
        onChanged(checked);
      },
      activeColor: colorScheme.primary,
      controlAffinity: ListTileControlAffinity.leading,
      secondary: Icon(
        icon,
        color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _DropdownContainer<T> extends StatelessWidget {
  const _DropdownContainer({
    required this.value,
    required this.enabled,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final bool enabled;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: colorScheme.surfaceContainerHighest,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: colorScheme.primary,
          ),
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          items: items,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}
