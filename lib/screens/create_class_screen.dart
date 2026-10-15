import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/hive_constants.dart';
import '../data/backup_reminder.dart';
import '../data/models/class_entry.dart';
import '../widgets/app_ui.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  static const _uuid = Uuid();
  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final _titleController = TextEditingController();
  final _titleFieldKey = GlobalKey();
  final _daysKey = GlobalKey();
  final List<int> _weekdays = <int>[];
  final Map<int, int> _weekdayHours = <int, int>{};
  final Map<int, int> _weekdayMinutes = <int, int>{};
  String _classType = ClassTypes.lecture;
  int _defaultStartHour = 9;
  int _defaultStartMinute = 0;
  bool _saving = false;
  bool _attempted = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickTimeFor(int weekday) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _weekdayHours[weekday] ?? _defaultStartHour,
        minute: _weekdayMinutes[weekday] ?? _defaultStartMinute,
      ),
      helpText: 'Select start time for ${_dayNames[weekday]}',
    );
    if (picked != null && mounted) {
      setState(() {
        _weekdayHours[weekday] = picked.hour;
        _weekdayMinutes[weekday] = picked.minute;
        _defaultStartHour = picked.hour;
        _defaultStartMinute = picked.minute;
      });
    }
  }

  /// Scrolls the form so the first invalid field is visible.
  void _scrollToFirstInvalid(String title) {
    final target = title.isEmpty
        ? _titleFieldKey.currentContext
        : _daysKey.currentContext;
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.1,
        duration: const Duration(milliseconds: 250),
      );
    });
  }

  Future<void> _createClass() async {
    if (_saving) return;
    // Dismiss the keyboard so the whole form stays visible while validating.
    FocusScope.of(context).unfocus();
    setState(() => _attempted = true);
    final title = _titleController.text.trim();
    if (title.isEmpty || _weekdays.isEmpty) {
      _scrollToFirstInvalid(title);
      return;
    }

    final box = Hive.box<ClassEntry>(HiveConstants.classBox);

    setState(() => _saving = true);
    try {
      final hours = <String, int>{
        for (final day in _weekdays)
          '$day': _weekdayHours[day] ?? _defaultStartHour,
      };
      final minutes = <String, int>{
        for (final day in _weekdays)
          '$day': _weekdayMinutes[day] ?? _defaultStartMinute,
      };
      final entry = ClassEntry(
        classId: _uuid.v4(),
        title: title,
        weekdays: List<int>.from(_weekdays)..sort(),
        startHour: hours.values.first,
        weekdayHours: hours,
        weekdayMinutes: minutes,
        classType: _classType,
        totalStudents: 0,
        students: <String, String>{},
      );
      await box.put(entry.classId, entry);
      await BackupReminder.recordDataChange();
      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      await Navigator.of(context)
          .pushReplacementNamed('/roster', arguments: entry);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not create class')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleMissing = _attempted && _titleController.text.trim().isEmpty;
    final weekdaysMissing = _attempted && _weekdays.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Create class')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: const LinearProgressIndicator(
                    value: 0.5,
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('Step 1 of 2', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          Text('Class details', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Set up the class, then add students.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            key: _titleFieldKey,
            controller: _titleController,
            enabled: !_saving,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Class name',
              errorText: titleMissing ? 'Enter a class name' : null,
            ),
          ),
          const SizedBox(height: 16),
          Text('Class type', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: ClassTypes.lecture,
                label: Text('Lecture'),
                icon: Icon(Icons.menu_book_outlined),
              ),
              ButtonSegment(
                value: ClassTypes.lab,
                label: Text('Lab'),
                icon: Icon(Icons.science_outlined),
              ),
            ],
            selected: {_classType},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 13),
            ),
            onSelectionChanged: _saving
                ? null
                : (selection) => setState(() {
                    _classType = selection.first;
                  }),
          ),
          const SizedBox(height: 8),
          Text(
            'Create separate classes for lecture and lab.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          Text('Class days', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          WeekdaySelector(
            key: _daysKey,
            selectedDays: _weekdays,
            enabled: !_saving,
            onChanged: (index) {
              setState(() {
                if (!_weekdays.remove(index)) {
                  _weekdays.add(index);
                  _weekdayHours[index] ??= _defaultStartHour;
                  _weekdayMinutes[index] ??= _defaultStartMinute;
                }
                _weekdays.sort();
              });
            },
          ),
          if (weekdaysMissing) ...[
            const SizedBox(height: 8),
            Text(
              'Select at least one weekday',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final day in _weekdays) ...[
            AppSurface(
              radius: 12,
              child: ListTile(
                title: Text(_dayNames[day]),
                subtitle: Text(
                  TimeOfDay(
                    hour: _weekdayHours[day] ?? _defaultStartHour,
                    minute: _weekdayMinutes[day] ?? _defaultStartMinute,
                  ).format(context),
                ),
                trailing: const Icon(Icons.schedule_outlined),
                onTap: _saving ? null : () => _pickTimeFor(day),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        onPressed: _saving ? null : _createClass,
        child: _saving
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('Creating...'),
                ],
              )
            : const Text('Continue to students'),
      ),
    );
  }
}
