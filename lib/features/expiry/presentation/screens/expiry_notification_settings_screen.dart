import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/notifications/browser_notification_service.dart';
import '../../domain/services/expiry_notification_provider.dart';
import '../providers/expiry_notification_settings_provider.dart';

class ExpiryNotificationSettingsScreen extends ConsumerStatefulWidget {
  const ExpiryNotificationSettingsScreen({super.key});

  @override
  ConsumerState<ExpiryNotificationSettingsScreen> createState() =>
      _ExpiryNotificationSettingsScreenState();
}

class _ExpiryNotificationSettingsScreenState
    extends ConsumerState<ExpiryNotificationSettingsScreen> {
  late bool _notificationsEnabled;
  late bool _expiringSoonEnabled;
  late bool _expiredItemsEnabled;
  late bool _useFirstEnabled;
  late int _daysBefore;
  late TimeOfDay _notificationTime;
  late String _frequency;
  late BrowserNotificationPermission _browserPermission;
  bool _browserBusy = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(expiryNotificationSettingsProvider);
    _notificationsEnabled = settings.notificationsEnabled;
    _expiringSoonEnabled = settings.expiringSoonEnabled;
    _expiredItemsEnabled = settings.expiredItemsEnabled;
    _useFirstEnabled = settings.useFirstEnabled;
    _daysBefore = settings.daysBefore;
    _notificationTime = settings.notificationTime;
    _frequency = settings.frequency;
    _browserPermission = ref
        .read(browserNotificationServiceProvider)
        .permission;
  }

  Future<void> _enableBrowserPopups() async {
    if (_browserBusy) return;
    final browser = ref.read(browserNotificationServiceProvider);
    // Start the permission prompt directly from the click, before persistence.
    final permissionRequest = browser.requestPermission();
    setState(() => _browserBusy = true);
    try {
      final permission = await permissionRequest;
      if (!mounted) return;
      setState(() => _browserPermission = permission);
      if (permission == BrowserNotificationPermission.granted) {
        final shown = await browser.show(
          title: 'Expiry pop-ups enabled',
          body: 'You will receive pop-ups for pantry items nearing expiry.',
          tag: 'expiry-notification-test',
        );
        if (!shown && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'The browser could not show the test notification.',
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not enable browser pop-ups. Check site notification permissions.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _browserBusy = false);
    }
  }

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

  Future<void> _saveChanges() async {
    final newState = ExpiryNotificationSettingsState(
      notificationsEnabled: _notificationsEnabled,
      expiringSoonEnabled: _expiringSoonEnabled,
      expiredItemsEnabled: _expiredItemsEnabled,
      useFirstEnabled: _useFirstEnabled,
      daysBefore: _daysBefore,
      notificationTime: _notificationTime,
      frequency: _frequency,
    );

    await ref
        .read(expiryNotificationSettingsProvider.notifier)
        .saveSettings(newState);

    if (_notificationsEnabled) {
      await ref
          .read(expiryNotificationServiceProvider)
          .showExpiryNotification(
            title: "Expiry Notifications Enabled",
            body:
                "You will receive alerts for expiring and expired pantry items.",
          );
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expiry notification settings saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = featurePageBackground(context);
    final headingColor = isDark ? colorScheme.onSurface : FreshPalette.heading;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: backgroundColor,
        foregroundColor: headingColor,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: headingColor),
        ),
        title: Text(
          'Expiry Notifications',
          style: TextStyle(
            color: headingColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
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

              if (kIsWeb ||
                  _browserPermission !=
                      BrowserNotificationPermission.unavailable) ...[
                const SizedBox(height: 16),
                Material(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Browser pop-up notifications',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(switch (_browserPermission) {
                          BrowserNotificationPermission.granted =>
                            'Browser pop-ups are allowed. Send a test to check them.',
                          BrowserNotificationPermission.denied =>
                            'Notifications are blocked. Allow notifications in the browser site settings, then try again.',
                          BrowserNotificationPermission.unavailable =>
                            'Browser pop-ups require a supported browser using HTTPS or localhost. Alerts still appear inside the app.',
                          BrowserNotificationPermission.notRequested =>
                            'Allow browser notifications to see expiry pop-ups outside the app. Alerts also appear inside the app.',
                        }, style: theme.textTheme.bodyMedium),
                        if (_browserPermission !=
                            BrowserNotificationPermission.unavailable) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _browserBusy || !_notificationsEnabled
                                ? null
                                : _enableBrowserPopups,
                            icon: const Icon(
                              Icons.notifications_active_outlined,
                            ),
                            label: Text(
                              _browserBusy
                                  ? 'Please wait...'
                                  : _browserPermission ==
                                        BrowserNotificationPermission.granted
                                  ? 'Send test pop-up'
                                  : 'Enable browser pop-ups',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 26),

              const _SectionTitle(title: 'Notify me for'),

              const SizedBox(height: 10),

              Material(
                color: colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: colorScheme.outline),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
