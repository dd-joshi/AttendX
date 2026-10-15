import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/app_theme.dart';
import '../core/hive_constants.dart';
import '../data/class_roster_service.dart';
import '../data/models/class_entry.dart';
import '../widgets/app_ui.dart';
import '../widgets/student_name_edit_dialog.dart';

class ManageClassScreen extends StatefulWidget {
  const ManageClassScreen({super.key, required this.classEntry});

  final ClassEntry classEntry;

  @override
  State<ManageClassScreen> createState() => _ManageClassScreenState();
}

class _ManageClassScreenState extends State<ManageClassScreen> {
  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  late ClassEntry _classEntry;
  late final TextEditingController _titleController;
  late List<int> _weekdays;
  late Map<int, int> _weekdayHours;
  late Map<int, int> _weekdayMinutes;
  bool _saving = false;
  int? _updatingNameRoll;

  bool get _isBusy => _saving || _updatingNameRoll != null;

  Map<String, int> get _effectiveHours => {
    for (final day in _weekdays)
      '$day': _weekdayHours[day] ?? _classEntry.startHour,
  };

  Map<String, int> get _effectiveMinutes => {
    for (final day in _weekdays)
      '$day': _weekdayMinutes[day] ?? _classEntry.minuteForWeekday(day),
  };

  bool get _detailsDirty {
    if (_titleController.text.trim() != _classEntry.title ||
        _weekdays.length != _classEntry.weekdays.length) {
      return true;
    }
    for (final day in _weekdays) {
      if (!_classEntry.weekdays.contains(day) ||
          (_weekdayHours[day] ?? _classEntry.startHour) !=
              _classEntry.hourForWeekday(day) ||
          (_weekdayMinutes[day] ?? _classEntry.minuteForWeekday(day)) !=
              _classEntry.minuteForWeekday(day)) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _classEntry = widget.classEntry;
    _titleController = TextEditingController(text: _classEntry.title);
    _weekdays = List<int>.from(_classEntry.weekdays);
    _weekdayHours = {
      for (final day in _classEntry.weekdays)
        day: _classEntry.hourForWeekday(day),
    };
    _weekdayMinutes = {
      for (final day in _classEntry.weekdays)
        day: _classEntry.minuteForWeekday(day),
    };
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _adoptClass(ClassEntry entry) {
    setState(() {
      _classEntry = entry;
      _titleController.text = entry.title;
      _weekdays = List<int>.from(entry.weekdays);
      _weekdayHours = {
        for (final day in entry.weekdays) day: entry.hourForWeekday(day),
      };
      _weekdayMinutes = {
        for (final day in entry.weekdays) day: entry.minuteForWeekday(day),
      };
    });
  }

  Future<void> _reloadClass() async {
    final current = Hive.box<ClassEntry>(HiveConstants.classBox)
        .get(_classEntry.classId);
    if (current != null && mounted) _adoptClass(current);
  }

  Future<void> _pickTimeFor(int weekday) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _weekdayHours[weekday] ?? _classEntry.startHour,
        minute:
            _weekdayMinutes[weekday] ?? _classEntry.minuteForWeekday(weekday),
      ),
      helpText: 'Select start time for ${_dayNames[weekday]}',
    );
    if (picked != null && mounted) {
      setState(() {
        _weekdayHours[weekday] = picked.hour;
        _weekdayMinutes[weekday] = picked.minute;
      });
    }
  }

  Future<bool> _saveDetails({bool showMessage = true}) async {
    if (_isBusy) return false;
    // Dismiss the keyboard so the form and feedback stay visible.
    FocusScope.of(context).unfocus();
    if (_titleController.text.trim().isEmpty || _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a class name and weekday')),
      );
      return false;
    }

    setState(() => _saving = true);
    try {
      final hours = _effectiveHours;
      final updated = await updateClassDetails(
        classId: _classEntry.classId,
        title: _titleController.text,
        weekdays: _weekdays,
        startHour: hours.values.first,
        weekdayHours: hours,
        weekdayMinutes: _effectiveMinutes,
      );
      if (!mounted) return false;
      _adoptClass(updated);
      if (showMessage) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Class details saved')));
        unawaited(HapticFeedback.mediumImpact());
      }
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save class details')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _saveBeforeRosterIfNeeded() async {
    if (!_detailsDirty) return true;
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save class changes?'),
        content: const Text(
          'Save the class name and schedule before managing its roster.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Save & continue'),
          ),
        ],
      ),
    );
    return shouldSave == true && await _saveDetails(showMessage: false);
  }

  Future<void> _openRoster() async {
    if (_isBusy) return;
    if (!await _saveBeforeRosterIfNeeded() || !mounted) return;
    await Navigator.of(context).pushNamed('/roster', arguments: _classEntry);
    await _reloadClass();
  }

  Future<void> _editName(int roll) async {
    if (_isBusy) return;
    final rollLabel = roll.toString().padLeft(2, '0');
    final name = await showDialog<String>(
      context: context,
      builder: (_) => StudentNameEditDialog(
        rollLabel: rollLabel,
        initialName: _classEntry.students[rollLabel] ?? '',
      ),
    );
    if (name == null || !mounted) return;

    setState(() => _updatingNameRoll = roll);
    try {
      final updated = await saveStudentNameCorrection(
        classId: _classEntry.classId,
        roll: roll,
        name: name,
      );
      if (!mounted) return;
      setState(() => _classEntry = updated);
      unawaited(HapticFeedback.mediumImpact());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update student name')),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingNameRoll = null);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (_isBusy) return false;
    if (!_detailsDirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Discard class changes?'),
            content: const Text(
              'The class name or schedule has not been saved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final rosterSize = _classEntry.rosterSize;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!await _confirmDiscard() || !context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Manage class')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              'Class details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Update the class name or regular schedule.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              enabled: !_isBusy,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Class name'),
            ),
            const SizedBox(height: 12),
            AppSurface(
              radius: 12,
              child: ListTile(
                title: const Text('Class type'),
                subtitle: Text('${_classEntry.classTypeLabel} class'),
                trailing: Icon(
                  _classEntry.effectiveClassType == ClassTypes.lab
                      ? Icons.science_outlined
                      : Icons.menu_book_outlined,
                  color: _classEntry.effectiveClassType == ClassTypes.lab
                      ? AppColors.lab
                      : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Class days', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            WeekdaySelector(
              selectedDays: _weekdays,
              enabled: !_isBusy,
              onChanged: (index) {
                setState(() {
                  if (!_weekdays.remove(index)) {
                    _weekdays.add(index);
                    _weekdayHours[index] ??= _classEntry.startHour;
                    _weekdayMinutes[index] ??= 0;
                  }
                  _weekdays.sort();
                });
              },
            ),
            const SizedBox(height: 12),
            for (final day in _weekdays) ...[
              AppSurface(
                radius: 12,
                child: ListTile(
                  title: Text(_dayNames[day]),
                  subtitle: Text(
                    TimeOfDay(
                      hour: _weekdayHours[day] ?? _classEntry.startHour,
                      minute:
                          _weekdayMinutes[day] ??
                          _classEntry.minuteForWeekday(day),
                    ).format(context),
                  ),
                  trailing: const Icon(Icons.schedule_outlined),
                  onTap: _isBusy ? null : () => _pickTimeFor(day),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 32),
            _RosterHeader(
              count: rosterSize,
              hasRoster: rosterSize > 0,
              onPressed: _isBusy ? null : _openRoster,
            ),
            if (rosterSize == 0)
              const InlineMessage(
                child: Text(
                  'Roster not added. Add student names before taking attendance.',
                ),
              )
            else ...[
              Text(
                'Use the pencil only to correct an existing name.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              AppSurface(
                child: Column(
                  children: List<Widget>.generate(rosterSize * 2 - 1, (index) {
                    if (index.isOdd) {
                      return const Divider(indent: 16, endIndent: 16);
                    }
                    final roll = index ~/ 2 + 1;
                    final rollLabel = roll.toString().padLeft(2, '0');
                    final name = _classEntry.students[rollLabel] ?? '';
                    return ListTile(
                      minTileHeight: 56,
                      leading: SizedBox(width: 36, child: Text(rollLabel)),
                      title: Text(name.isEmpty ? 'Name not added' : name),
                      trailing: _updatingNameRoll == roll
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              tooltip: 'Edit name',
                              onPressed: _isBusy ? null : () => _editName(roll),
                              icon: const Icon(Icons.edit_outlined, size: 21),
                            ),
                    );
                  }),
                ),
              ),
            ],
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          onPressed: _detailsDirty && !_isBusy ? () => _saveDetails() : null,
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
                    Text('Saving...'),
                  ],
                )
              : const Text('Save class details'),
        ),
      ),
    );
  }
}

class _RosterHeader extends StatelessWidget {
  const _RosterHeader({
    required this.count,
    required this.hasRoster,
    required this.onPressed,
  });

  final int count;
  final bool hasRoster;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      'Roster \u00B7 $count students',
      style: Theme.of(context).textTheme.titleMedium,
    );
    final action = TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
      label: Text(hasRoster ? 'Update roster' : 'Add roster'),
    );
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    if (largeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, action, const SizedBox(height: 4)],
      );
    }

    return Row(
      children: [
        Expanded(child: title),
        action,
      ],
    );
  }
}
