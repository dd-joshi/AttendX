import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/app_theme.dart';
import '../core/hive_constants.dart';
import '../data/models/class_entry.dart';
import '../data/models/snapshot_entry.dart';
import '../providers/attendance_grid_notifier.dart';
import '../widgets/app_ui.dart';
import '../widgets/student_name_edit_dialog.dart';

class AttendanceGridScreen extends ConsumerStatefulWidget {
  const AttendanceGridScreen({super.key, required this.classEntry});

  final ClassEntry classEntry;

  @override
  ConsumerState<AttendanceGridScreen> createState() =>
      _AttendanceGridScreenState();
}

class _AttendanceGridScreenState extends ConsumerState<AttendanceGridScreen> {
  bool _showNameCards = true;
  bool _topicEditing = false;
  late final TextEditingController _topicController;
  late final FocusNode _topicFocus;

  String get _viewPreferenceKey =>
      'attendance_name_cards_${widget.classEntry.classId}';

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController();
    _topicFocus = FocusNode()..addListener(_onTopicFocusChange);
    _showNameCards =
        Hive.box<dynamic>(HiveConstants.settingsBox)
                .get(_viewPreferenceKey, defaultValue: true)
            as bool? ??
        true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(attendanceGridNotifier.notifier).loadClass(widget.classEntry);
    });
  }

  void _onTopicFocusChange() {
    if (!_topicFocus.hasFocus && _topicEditing && mounted) {
      setState(() => _topicEditing = false);
    }
  }

  void _startTopicEdit() {
    setState(() => _topicEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _topicFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _topicFocus.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _toggleAttendanceView() async {
    final showNameCards = !_showNameCards;
    setState(() => _showNameCards = showNameCards);
    try {
      await Hive.box<dynamic>(HiveConstants.settingsBox)
          .put(_viewPreferenceKey, showNameCards);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the view preference')),
      );
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Attendance changes have not been saved.'),
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
    );
    return shouldDiscard ?? false;
  }

  Future<bool> _onWillPop() async {
    final state = ref.read(attendanceGridNotifier);
    if (state.isSaving) return false;
    if (!state.isDirty) return true;
    return _confirmDiscardChanges();
  }

  Future<void> _pickAttendanceDate() async {
    final state = ref.read(attendanceGridNotifier);
    final today = AttendanceGridNotifier.dateOnly(DateTime.now());
    final currentDate = state.selectedDate ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked == null ||
        AttendanceGridNotifier.isSameDate(picked, currentDate)) {
      return;
    }
    if (!mounted) return;

    if (ref.read(attendanceGridNotifier).isDirty &&
        !await _confirmDiscardChanges()) {
      return;
    }
    if (!mounted) return;
    ref.read(attendanceGridNotifier.notifier).selectDate(picked);
  }

  Future<void> _deleteAttendance() async {
    final state = ref.read(attendanceGridNotifier);
    final date = state.selectedDate;
    if (state.isSaving || !state.hasExistingAttendance || date == null) return;

    final label = formatAppDate(date);
    final sessionLabel = state.sessionType == SessionTypes.lab
        ? 'lab'
        : 'lecture';
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete attendance?'),
        content: Text(
          'Delete $sessionLabel attendance for $label? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.absent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    try {
      await ref
          .read(attendanceGridNotifier.notifier)
          .deleteSelectedAttendance();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('Attendance deleted for $label')),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Could not delete attendance')),
        );
    }
  }

  Future<void> _saveAttendance() async {
    FocusScope.of(context).unfocus();
    final before = ref.read(attendanceGridNotifier);
    final absent = before.absentRolls.length;
    final present = before.roster.length - absent;

    try {
      final result = await ref
          .read(attendanceGridNotifier.notifier)
          .saveAttendance();
      if (!mounted) return;

      final message = switch (result) {
        AttendanceSaveResult.created =>
          'Saved. Present: $present \u00B7 Absent: $absent',
        AttendanceSaveResult.updated =>
          'Updated. Present: $present \u00B7 Absent: $absent',
        AttendanceSaveResult.existingLoaded =>
          'Attendance already existed and has been loaded',
      };
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
      unawaited(HapticFeedback.mediumImpact());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: const Text('Could not save attendance'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_saveAttendance()),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceGridNotifier);
    ref.listen(attendanceGridNotifier, (previous, next) {
      final recordChanged =
          previous == null ||
          previous.selectedDate != next.selectedDate ||
          previous.sessionType != next.sessionType ||
          previous.editingSnapshotId != next.editingSnapshotId;
      if (recordChanged) {
        if (_topicController.text != next.topic) {
          _topicController.text = next.topic;
        }
        if (_topicEditing) {
          setState(() => _topicEditing = false);
        }
      }
    });
    final absentCount = state.absentRolls.length;
    final presentCount = state.roster.length - absentCount;
    final selectedDate = state.selectedDate ?? DateTime.now();
    final today = AttendanceGridNotifier.dateOnly(DateTime.now());
    final isToday = AttendanceGridNotifier.isSameDate(selectedDate, today);
    final dateLabel = formatAppDate(selectedDate);
    final canSave =
        !state.isSaving &&
        state.activeClass != null &&
        state.roster.isNotEmpty &&
        (!state.hasExistingAttendance || state.isDirty);
    final isSaved = state.hasExistingAttendance && !state.isDirty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _onWillPop();
        if (!context.mounted || !shouldLeave) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: Text(state.activeClass?.title ?? widget.classEntry.title),
          actions: [
            IconButton(
              icon: Icon(
                _showNameCards ? Icons.grid_view : Icons.view_module_outlined,
              ),
              tooltip: _showNameCards ? 'Number grid' : 'Name cards',
              onPressed: _toggleAttendanceView,
            ),
            if (state.hasExistingAttendance)
              PopupMenuButton<String>(
                enabled: !state.isSaving,
                tooltip: 'More',
                onSelected: (value) {
                  if (value == 'delete') unawaited(_deleteAttendance());
                },
                itemBuilder: (_) => const [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text(
                      'Delete attendance',
                      style: TextStyle(color: AppColors.absent),
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 16, 2),
              child: Row(
                children: [
                  Flexible(
                    child: Tooltip(
                      message: 'Change attendance date',
                      child: InkWell(
                        onTap: state.isSaving ? null : _pickAttendanceDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_month_outlined,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isToday) ...[
                                      const _TodayBadge(),
                                      const SizedBox(width: 6),
                                    ],
                                    Flexible(
                                      child: Text(
                                        dateLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.expand_more,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _SessionTypeChip(
                    sessionType: widget.classEntry.effectiveClassType,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
              child: _topicEditing
                  ? TextField(
                      controller: _topicController,
                      focusNode: _topicFocus,
                      enabled: !state.isSaving,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (value) => ref
                          .read(attendanceGridNotifier.notifier)
                          .setTopic(value),
                      onSubmitted: (_) => setState(() => _topicEditing = false),
                      decoration: const InputDecoration(
                        labelText: 'Topic (optional)',
                        hintText: 'e.g. Unit 2 \u2014 Transformers',
                        helperText: 'Optional \u00B7 up to 40 characters',
                        isDense: true,
                        counterStyle: TextStyle(fontSize: 11),
                      ),
                    )
                  : Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: state.isSaving ? null : _startTopicEdit,
                        child: IgnorePointer(
                          child: TextField(
                            controller: _topicController,
                            readOnly: true,
                            enabled: !state.isSaving,
                            decoration: const InputDecoration(
                              labelText: 'Topic (optional)',
                              hintText: 'Add topic',
                              helperText: 'Optional \u00B7 up to 40 characters',
                              isDense: true,
                              suffixIcon: Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final summary = Text(
                    '$presentCount present \u00B7 $absentCount absent',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w500),
                  );
                  final allPresent = TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      textStyle: const TextStyle(fontSize: 12),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: state.isSaving || state.roster.isEmpty
                        ? null
                        : () {
                            unawaited(HapticFeedback.lightImpact());
                            ref
                                .read(attendanceGridNotifier.notifier)
                                .markAllPresent();
                          },
                    child: const Text('All present'),
                  );
                  final allAbsent = TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      textStyle: const TextStyle(fontSize: 12),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: state.isSaving || state.roster.isEmpty
                        ? null
                        : () {
                            unawaited(HapticFeedback.lightImpact());
                            ref
                                .read(attendanceGridNotifier.notifier)
                                .markAllAbsent();
                          },
                    child: const Text('All absent'),
                  );

                  final largeText =
                      MediaQuery.textScalerOf(context).scale(1) > 1.25;
                  if (constraints.maxWidth < 330 || largeText) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                          child: summary,
                        ),
                        Row(
                          children: [
                            Expanded(child: allPresent),
                            Expanded(child: allAbsent),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: summary),
                      allPresent,
                      allAbsent,
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScale = MediaQuery.textScalerOf(context).scale(1);
                  final compactColumns = constraints.maxWidth < 344 ? 5 : 6;
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                    gridDelegate: _showNameCards
                        ? SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            mainAxisExtent: textScale > 1.3 ? 62 : 50,
                          )
                        : SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: compactColumns,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            childAspectRatio: 1.1,
                          ),
                    itemCount: state.roster.length,
                    physics: const ClampingScrollPhysics(),
                    itemBuilder: (context, index) {
                      return AttendanceCell(
                        student: state.roster[index],
                        showName: _showNameCards,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          onPressed: canSave ? _saveAttendance : null,
          child: state.isSaving
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      state.hasExistingAttendance ? 'Updating...' : 'Saving...',
                    ),
                  ],
                )
              : isSaved
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 18),
                        SizedBox(width: 8),
                        Text('Saved'),
                      ],
                    )
                  : Text(
                      state.hasExistingAttendance ? 'Update' : 'Save',
                    ),
        ),
      ),
    );
  }
}

class _TodayBadge extends StatelessWidget {
  const _TodayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Today',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryPressed,
        ),
      ),
    );
  }
}

class AttendanceCell extends ConsumerStatefulWidget {
  const AttendanceCell({
    super.key,
    required this.student,
    required this.showName,
  });

  final AttendanceStudent student;
  final bool showName;

  @override
  ConsumerState<AttendanceCell> createState() => _AttendanceCellState();
}

class _AttendanceCellState extends ConsumerState<AttendanceCell> {
  bool _isPressed = false;

  String get _rollStr => widget.student.rollLabel;

  void _setPressed(bool value) {
    if (!mounted || _isPressed == value) return;
    setState(() => _isPressed = value);
  }

  void _toggleAttendance() {
    unawaited(HapticFeedback.selectionClick());
    ref.read(attendanceGridNotifier.notifier).toggleRoll(widget.student.roll);
  }

  Future<void> _editName() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => StudentNameEditDialog(
        rollLabel: _rollStr,
        initialName: widget.student.name,
      ),
    );
    if (newName == null || !mounted) return;
    try {
      await ref
          .read(attendanceGridNotifier.notifier)
          .updateStudentName(roll: widget.student.roll, name: newName);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update student name. Try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAbsent = ref.watch(
      attendanceGridNotifier.select(
        (s) => s.absentRolls.contains(widget.student.roll),
      ),
    );
    final isSaving = ref.watch(
      attendanceGridNotifier.select((s) => s.isSaving),
    );

    final color = isAbsent
        ? (_isPressed ? AppColors.absentPressed : AppColors.absent)
        : (_isPressed
              ? AppColors.presentPressedBackground
              : AppColors.presentBackground);
    final rollColor = isAbsent ? Colors.white : AppColors.present;
    final nameColor = isAbsent ? Colors.white : AppColors.textPrimary;
    final name = widget.student.name;

    final studentLabel = name.isEmpty ? 'unnamed student' : name;

    final attendanceCell = AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: isSaving ? null : _toggleAttendance,
          onLongPress: widget.showName && !isSaving
              ? () => unawaited(_editName())
              : null,
          splashColor: isAbsent
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.06),
          highlightColor: Colors.transparent,
          child: widget.showName
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          _rollStr,
                          style: TextStyle(
                            color: rollColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: nameColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (isAbsent) ...[
                        const SizedBox(width: 4),
                        const Text(
                          'Absent',
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : Center(
                  child: Text(
                    _rollStr,
                    style: TextStyle(
                      color: rollColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
      ),
    );

    final interactiveCell = widget.showName
        ? attendanceCell
        : Tooltip(
            message: name.trim().isEmpty ? 'Unnamed student' : name.trim(),
            triggerMode: TooltipTriggerMode.longPress,
            preferBelow: false,
            verticalOffset: 8,
            positionDelegate: (position) => positionDependentBox(
              size: position.overlaySize,
              childSize: position.tooltipSize,
              target: position.target,
              verticalOffset:
                  position.targetSize.height / 2 + position.verticalOffset,
              preferBelow: position.preferBelow,
            ),
            showDuration: const Duration(milliseconds: 1800),
            exitDuration: const Duration(milliseconds: 100),
            enableFeedback: true,
            excludeFromSemantics: true,
            constraints: const BoxConstraints(minHeight: 38, maxWidth: 240),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            onTriggered: () => _setPressed(false),
            child: attendanceCell,
          );

    return Semantics(
      button: true,
      enabled: !isSaving,
      onTap: isSaving ? null : _toggleAttendance,
      onLongPress: widget.showName && !isSaving
          ? () => unawaited(_editName())
          : null,
      label:
          'Roll $_rollStr, $studentLabel, ${isAbsent ? 'Absent' : 'Present'}',
      hint: widget.showName
          ? '${isAbsent ? 'Tap to mark present.' : 'Tap to mark absent.'} '
                'Long press to edit name.'
          : '${isAbsent ? 'Tap to mark present.' : 'Tap to mark absent.'} '
                'Long press to show name.',
      excludeSemantics: true,
      child: interactiveCell,
    );
  }
}

/// Fixed "Lecture" or "Lab" pill for typed classes, where the session kind
/// is set by the class type instead of being selectable per date.
class _SessionTypeChip extends StatelessWidget {
  const _SessionTypeChip({required this.sessionType});

  final String sessionType;

  @override
  Widget build(BuildContext context) {
    final isLab = sessionType == SessionTypes.lab;
    final color = isLab ? AppColors.lab : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isLab ? AppColors.labSoft : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLab ? Icons.science_outlined : Icons.menu_book_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            isLab ? 'Lab' : 'Lecture',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
