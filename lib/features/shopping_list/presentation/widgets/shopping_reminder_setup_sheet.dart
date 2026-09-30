import 'package:flutter/material.dart';

import '../../domain/models/shopping_reminder.dart';

class ShoppingReminderSetupSheet extends StatefulWidget {
  const ShoppingReminderSetupSheet({
    super.key,
    required this.clock,
    this.initialReminder,
  });

  final DateTime Function() clock;
  final ShoppingReminder? initialReminder;

  @override
  State<ShoppingReminderSetupSheet> createState() =>
      _ShoppingReminderSetupSheetState();
}

class _ShoppingReminderSetupSheetState
    extends State<ShoppingReminderSetupSheet> {
  late DateTime _date;
  late int _count;
  late List<TimeOfDay> _times;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final now = widget.clock();
    final initial = widget.initialReminder;
    _date = initial?.date ?? DateTime(now.year, now.month, now.day);
    _count = initial?.count ?? 1;
    _times = _defaultTimes(_date);
    if (initial != null) {
      for (var index = 0; index < initial.times.length; index++) {
        _times[index] = TimeOfDay.fromDateTime(initial.times[index]);
      }
    }
  }

  List<TimeOfDay> _defaultTimes(DateTime date) {
    final now = widget.clock();
    final today = DateTime(now.year, now.month, now.day);
    if (date == today) {
      final candidates = [
        1,
        4,
        8,
      ].map((hours) => now.add(Duration(hours: hours))).toList();
      if (candidates.every(
        (time) => DateTime(time.year, time.month, time.day) == today,
      )) {
        return candidates.map(TimeOfDay.fromDateTime).toList();
      }
    }
    return const [
      TimeOfDay(hour: 10, minute: 0),
      TimeOfDay(hour: 15, minute: 0),
      TimeOfDay(hour: 18, minute: 0),
    ];
  }

  Future<void> _selectDate() async {
    final now = widget.clock();
    final today = DateTime(now.year, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: DateTime(today.year + 2, today.month, today.day),
      helpText: 'Shopping date',
    );
    if (selected == null) return;
    setState(() {
      _date = selected;
      _validationMessage = null;
    });
  }

  Future<void> _selectTime(int index) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _times[index],
      helpText: 'Reminder ${index + 1} time',
    );
    if (selected == null) return;
    setState(() {
      _times[index] = selected;
      _validationMessage = null;
    });
  }

  ShoppingReminder _buildReminder() => ShoppingReminder(
    date: _date,
    times: [
      for (var index = 0; index < _count; index++)
        DateTime(
          _date.year,
          _date.month,
          _date.day,
          _times[index].hour,
          _times[index].minute,
        ),
    ],
  );

  void _submit() {
    final reminder = _buildReminder();
    final validation = shoppingReminderValidationMessage(
      reminder,
      widget.clock(),
    );
    if (validation != null) {
      setState(() => _validationMessage = validation);
      return;
    }
    Navigator.pop(context, reminder);
  }

  String _fullDateLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _summaryTimes() {
    final labels = [
      for (var index = 0; index < _count; index++)
        _times[index].format(context),
    ];
    if (labels.length == 1) return labels.single;
    if (labels.length == 2) return '${labels.first} and ${labels.last}';
    return '${labels[0]}, ${labels[1]} and ${labels[2]}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Shopping Reminder',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 20),
            Text('Date', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('shopping-reminder-date'),
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(_fullDateLabel(_date)),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'How many reminders?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              key: const ValueKey('shopping-reminder-count'),
              segments: const [
                ButtonSegment(value: 1, label: Text('1')),
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
              ],
              selected: {_count},
              onSelectionChanged: (selection) => setState(() {
                _count = selection.single;
                _validationMessage = null;
              }),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 18),
            Text(
              'Reminder times',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            for (var index = 0; index < _count; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 28, child: Text('${index + 1}.')),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: ValueKey('shopping-reminder-time-$index'),
                        onPressed: () => _selectTime(index),
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text(_times[index].format(context)),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_count ${_count == 1 ? 'reminder' : 'reminders'} on ${_fullDateLabel(_date)}\n${_summaryTimes()}',
                key: const ValueKey('shopping-reminder-summary'),
              ),
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _validationMessage!,
                key: const ValueKey('shopping-reminder-validation'),
                style: TextStyle(color: colors.error),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('shopping-reminder-submit'),
                onPressed: _submit,
                icon: const Icon(Icons.alarm_add_outlined),
                label: const Text('Set Reminder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
