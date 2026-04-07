import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/models/class_entry.dart';
import '../data/models/snapshot_entry.dart';
import '../providers/attendance_grid_notifier.dart';
import '../widgets/export_bottom_sheet.dart';

class AttendanceGridScreen extends ConsumerStatefulWidget {
  const AttendanceGridScreen({
    super.key,
    required this.classEntry,
    this.existingSnapshot,
  });

  final ClassEntry classEntry;
  final SnapshotEntry? existingSnapshot;

  @override
  ConsumerState<AttendanceGridScreen> createState() =>
      _AttendanceGridScreenState();
}

class _AttendanceGridScreenState extends ConsumerState<AttendanceGridScreen> {
  bool _snapshotSavedSinceLastEdit = false;

  void _markSnapshotUnsaved() {
    if (!_snapshotSavedSinceLastEdit) return;
    setState(() {
      _snapshotSavedSinceLastEdit = false;
    });
  }

  Future<bool> _onWillPop() async {
    final hasUnsavedAbsences =
        ref.read(attendanceGridNotifier).absentRolls.isNotEmpty;
    final hasUnsavedSnapshot =
        hasUnsavedAbsences && !_snapshotSavedSinceLastEdit;
    if (!hasUnsavedSnapshot) return true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unsaved Attendance'),
        content: Text(
          widget.existingSnapshot != null
              ? 'Edited attendance not saved. Leave without saving?'
              : "You have marked absences that haven't been saved.\nLeave without saving?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    return shouldLeave ?? false;
  }

  @override
  void initState() {
    super.initState();
    _snapshotSavedSinceLastEdit = widget.existingSnapshot != null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceGridNotifier.notifier).loadClass(
            widget.classEntry,
            existingSnapshot: widget.existingSnapshot,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(
      attendanceGridNotifier.select((s) => s.isSaving),
    );
    final absentCount = ref.watch(
      attendanceGridNotifier.select((s) => s.absentRolls.length),
    );
    final presentCount = widget.classEntry.totalStudents - absentCount;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _onWillPop();
        if (!context.mounted || !shouldLeave) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existingSnapshot != null
                ? 'Edit \u00B7 ${DateFormat('dd MMM').format(widget.existingSnapshot!.timestamp)}'
                : widget.classEntry.title,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (ctx) => ExportBottomSheet(
                    preselectedClassId: widget.classEntry.classId,
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Present: $presentCount  |  Absent: $absentCount',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _markSnapshotUnsaved();
                      ref
                          .read(attendanceGridNotifier.notifier)
                          .markAllPresent();
                    },
                    child: const Text('All \u2713'),
                  ),
                  TextButton(
                    onPressed: () {
                      _markSnapshotUnsaved();
                      ref.read(attendanceGridNotifier.notifier).markAllAbsent();
                    },
                    child: const Text('All \u2717'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: widget.classEntry.totalStudents <= 60
                    ? SingleChildScrollView(
                        child: GridView.builder(
                          shrinkWrap: true,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            childAspectRatio: 1.1,
                          ),
                          itemCount: widget.classEntry.totalStudents,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final roll = index + 1;
                            return AttendanceCell(
                              roll: roll,
                              classEntry: widget.classEntry,
                              onToggleAbsence: _markSnapshotUnsaved,
                            );
                          },
                        ),
                      )
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: widget.classEntry.totalStudents,
                        physics: const ClampingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final roll = index + 1;
                          return AttendanceCell(
                            roll: roll,
                            classEntry: widget.classEntry,
                            onToggleAbsence: _markSnapshotUnsaved,
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: saving
              ? null
              : () async {
                  final absent =
                      ref.read(attendanceGridNotifier).absentRolls.length;
                  final present = widget.classEntry.totalStudents - absent;
                  await ref
                      .read(attendanceGridNotifier.notifier)
                      .saveSnapshot();
                  _snapshotSavedSinceLastEdit = true;
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Saved \u2713  Present: $present  \u00B7  Absent: $absent',
                      ),
                    ),
                  );
                  ref.read(attendanceGridNotifier.notifier).reset();
                },
          icon: saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(saving ? 'Saving...' : 'Save'),
        ),
      ),
    );
  }
}

class AttendanceCell extends ConsumerWidget {
  const AttendanceCell({
    super.key,
    required this.roll,
    required this.classEntry,
    required this.onToggleAbsence,
  });

  final int roll;
  final ClassEntry classEntry;
  final VoidCallback onToggleAbsence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAbsent = ref.watch(
      attendanceGridNotifier.select(
        (s) => s.absentRolls.contains(roll),
      ),
    );

    final rollStr = roll.toString().padLeft(2, '0');
    final color = isAbsent ? const Color(0xFFF44336) : const Color(0xFF4CAF50);

    return Tooltip(
      message: classEntry.students[rollStr] ?? '',
      triggerMode: TooltipTriggerMode.longPress,
      preferBelow: false,
      verticalOffset: 40,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            onToggleAbsence();
            ref.read(attendanceGridNotifier.notifier).toggleRoll(roll);
          },
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Text(
              rollStr,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
