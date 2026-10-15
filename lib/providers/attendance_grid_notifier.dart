import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/hive_constants.dart';
import '../data/backup_reminder.dart';
import '../data/class_roster_service.dart';
import '../data/models/class_entry.dart';
import '../data/models/snapshot_entry.dart';

enum AttendanceSaveResult { created, updated, existingLoaded }

@immutable
class AttendanceStudent {
  const AttendanceStudent({required this.roll, required this.name});

  final int roll;
  final String name;

  String get rollLabel => roll.toString().padLeft(2, '0');

  AttendanceStudent copyWith({String? name}) {
    return AttendanceStudent(roll: roll, name: name ?? this.name);
  }
}

class AttendanceGridState {
  const AttendanceGridState({
    this.activeClass,
    this.selectedDate,
    this.sessionType = SessionTypes.lecture,
    this.topic = '',
    this.baselineTopic = '',
    this.roster = const <AttendanceStudent>[],
    this.absentRolls = const <int>{},
    this.baselineAbsentRolls = const <int>{},
    this.editingSnapshotId,
    this.isSaving = false,
    this.isDirty = false,
  });

  final ClassEntry? activeClass;
  final DateTime? selectedDate;
  final String sessionType;
  final String topic;
  final String baselineTopic;
  final List<AttendanceStudent> roster;
  final Set<int> absentRolls;
  final Set<int> baselineAbsentRolls;
  final String? editingSnapshotId;
  final bool isSaving;
  final bool isDirty;

  bool get hasExistingAttendance => editingSnapshotId != null;

  AttendanceGridState copyWith({
    ClassEntry? activeClass,
    DateTime? selectedDate,
    String? sessionType,
    String? topic,
    String? baselineTopic,
    List<AttendanceStudent>? roster,
    Set<int>? absentRolls,
    Set<int>? baselineAbsentRolls,
    String? editingSnapshotId,
    bool? isSaving,
    bool? isDirty,
    bool clearEditingSnapshotId = false,
  }) {
    return AttendanceGridState(
      activeClass: activeClass ?? this.activeClass,
      selectedDate: selectedDate ?? this.selectedDate,
      sessionType: sessionType ?? this.sessionType,
      topic: topic ?? this.topic,
      baselineTopic: baselineTopic ?? this.baselineTopic,
      roster: roster ?? this.roster,
      absentRolls: absentRolls ?? this.absentRolls,
      baselineAbsentRolls: baselineAbsentRolls ?? this.baselineAbsentRolls,
      editingSnapshotId: clearEditingSnapshotId
          ? null
          : (editingSnapshotId ?? this.editingSnapshotId),
      isSaving: isSaving ?? this.isSaving,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}

class AttendanceGridNotifier extends StateNotifier<AttendanceGridState> {
  AttendanceGridNotifier() : super(const AttendanceGridState());

  static const _uuid = Uuid();

  static DateTime dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static bool isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void loadClass(ClassEntry classEntry, {DateTime? initialDate}) {
    final selectedDate = dateOnly(initialDate ?? DateTime.now());
    // A class is either a Lecture or a Lab, so the class type is the
    // session type of every attendance record it holds.
    _loadDateForClass(classEntry, selectedDate, classEntry.effectiveClassType);
  }

  void selectDate(DateTime date) {
    if (state.isSaving) return;
    final classEntry = state.activeClass;
    if (classEntry == null) return;
    _loadDateForClass(classEntry, dateOnly(date), state.sessionType);
  }

  void _loadDateForClass(
    ClassEntry classEntry,
    DateTime date,
    String sessionType,
  ) {
    final existing = _canonicalSnapshot(classEntry.classId, date, sessionType);
    final roster = existing == null
        ? _newRosterForDate(classEntry, date)
        : _snapshotRoster(existing);
    final activeRolls = roster.map((student) => student.roll).toSet();
    final absentRolls = _absentRollsFrom(existing)
      ..removeWhere((roll) => !activeRolls.contains(roll));

    state = AttendanceGridState(
      activeClass: classEntry,
      selectedDate: date,
      sessionType: sessionType,
      topic: existing?.topic ?? '',
      baselineTopic: existing?.topic ?? '',
      roster: roster,
      absentRolls: absentRolls,
      baselineAbsentRolls: absentRolls,
      editingSnapshotId: existing?.snapshotId,
    );
  }

  List<AttendanceStudent> _newRosterForDate(
    ClassEntry classEntry,
    DateTime date,
  ) {
    return activeRollsForDate(classEntry, date)
        .map((roll) {
          final rollLabel = roll.toString().padLeft(2, '0');
          return AttendanceStudent(
            roll: roll,
            name: classEntry.students[rollLabel] ?? '',
          );
        })
        .toList(growable: false);
  }

  List<AttendanceStudent> _snapshotRoster(SnapshotEntry snapshot) {
    final roster = <AttendanceStudent>[];
    for (final row in snapshot.snapshotData) {
      final roll = int.tryParse('${row['roll']}');
      if (roll == null) continue;
      roster.add(AttendanceStudent(roll: roll, name: '${row['name'] ?? ''}'));
    }
    return roster;
  }

  SnapshotEntry? _canonicalSnapshot(
    String classId,
    DateTime date,
    String sessionType,
  ) {
    SnapshotEntry? latest;
    for (final snapshot in Hive.box<SnapshotEntry>(
      HiveConstants.snapshotBox,
    ).values) {
      if (snapshot.classId != classId ||
          snapshot.effectiveSessionType != sessionType ||
          !isSameDate(snapshot.effectiveAttendanceDate, date)) {
        continue;
      }
      if (latest == null || snapshot.timestamp.isAfter(latest.timestamp)) {
        latest = snapshot;
      }
    }
    return latest;
  }

  Set<int> _absentRollsFrom(SnapshotEntry? snapshot) {
    final absentRolls = <int>{};
    if (snapshot == null) return absentRolls;

    for (final row in snapshot.snapshotData) {
      if (row['isAbsent'] == true) {
        final roll = int.tryParse('${row['roll']}');
        if (roll != null) absentRolls.add(roll);
      }
    }
    return absentRolls;
  }

  bool _isDirtyAfter(Set<int> absentRolls, [String? topic]) {
    if (!state.hasExistingAttendance) return true;
    return !setEquals(absentRolls, state.baselineAbsentRolls) ||
        (topic ?? state.topic) != state.baselineTopic;
  }

  void setTopic(String value) {
    if (state.isSaving) return;
    state = state.copyWith(
      topic: value,
      isDirty: _isDirtyAfter(state.absentRolls, value),
    );
  }

  void toggleRoll(int roll) {
    if (state.isSaving ||
        !state.roster.any((student) => student.roll == roll)) {
      return;
    }
    final next = Set<int>.from(state.absentRolls);
    if (!next.add(roll)) next.remove(roll);
    state = state.copyWith(absentRolls: next, isDirty: _isDirtyAfter(next));
  }

  void markAllPresent() {
    if (state.isSaving || state.roster.isEmpty) return;
    final next = <int>{};
    state = state.copyWith(absentRolls: next, isDirty: _isDirtyAfter(next));
  }

  void markAllAbsent() {
    if (state.isSaving || state.roster.isEmpty) return;
    final next = state.roster.map((student) => student.roll).toSet();
    state = state.copyWith(absentRolls: next, isDirty: _isDirtyAfter(next));
  }

  Future<void> updateStudentName({
    required int roll,
    required String name,
  }) async {
    if (state.isSaving) return;
    final classEntry = state.activeClass;
    if (classEntry == null) return;

    final updatedClass = await saveStudentNameCorrection(
      classId: classEntry.classId,
      roll: roll,
      name: name,
    );
    if (!mounted) return;
    final updatedName = updatedClass.students[roll.toString().padLeft(2, '0')];
    final roster = state.roster
        .map((student) {
          return student.roll == roll
              ? student.copyWith(name: updatedName)
              : student;
        })
        .toList(growable: false);

    state = state.copyWith(activeClass: updatedClass, roster: roster);
  }

  List<Map<String, dynamic>> _buildSnapshotData() {
    return state.roster
        .map((student) {
          return <String, dynamic>{
            'roll': student.rollLabel,
            'name': student.name,
            'isAbsent': state.absentRolls.contains(student.roll),
          };
        })
        .toList(growable: false);
  }

  Future<AttendanceSaveResult> saveAttendance() async {
    if (state.isSaving) {
      throw StateError('Attendance is already being saved');
    }
    final classEntry = state.activeClass;
    final selectedDate = state.selectedDate;
    if (classEntry == null || selectedDate == null) {
      throw StateError('No class or attendance date selected');
    }
    if (state.roster.isEmpty) {
      throw StateError('Add a roster before saving attendance');
    }

    state = state.copyWith(isSaving: true);
    try {
      final box = Hive.box<SnapshotEntry>(HiveConstants.snapshotBox);
      final editingSnapshotId = state.editingSnapshotId;
      final topic = state.topic.trim();

      if (editingSnapshotId != null) {
        SnapshotEntry? existing;
        for (final snapshot in box.values) {
          if (snapshot.snapshotId == editingSnapshotId) {
            existing = snapshot;
            break;
          }
        }
        if (existing == null) {
          throw StateError('Saved attendance could not be found');
        }

        await box.put(
          existing.key,
          SnapshotEntry(
            snapshotId: existing.snapshotId,
            timestamp: existing.timestamp,
            attendanceDate: selectedDate,
            sessionType: state.sessionType,
            topic: topic.isEmpty ? null : topic,
            classId: classEntry.classId,
            classTitle: classEntry.title,
            snapshotData: _buildSnapshotData(),
          ),
        );
        await BackupReminder.recordDataChange();
        if (!mounted) return AttendanceSaveResult.updated;

        state = state.copyWith(
          baselineAbsentRolls: state.absentRolls,
          baselineTopic: state.topic,
          isDirty: false,
        );
        return AttendanceSaveResult.updated;
      }

      final duplicate = _canonicalSnapshot(
        classEntry.classId,
        selectedDate,
        state.sessionType,
      );
      if (duplicate != null) {
        _loadDateForClass(classEntry, selectedDate, state.sessionType);
        return AttendanceSaveResult.existingLoaded;
      }

      final entry = SnapshotEntry(
        snapshotId: _uuid.v4(),
        timestamp: DateTime.now(),
        attendanceDate: selectedDate,
        sessionType: state.sessionType,
        topic: topic.isEmpty ? null : topic,
        classId: classEntry.classId,
        classTitle: classEntry.title,
        snapshotData: _buildSnapshotData(),
      );
      await box.add(entry);
      await BackupReminder.recordDataChange();
      if (!mounted) return AttendanceSaveResult.created;

      state = state.copyWith(
        editingSnapshotId: entry.snapshotId,
        baselineAbsentRolls: state.absentRolls,
        baselineTopic: state.topic,
        isDirty: false,
      );
      return AttendanceSaveResult.created;
    } finally {
      if (mounted) state = state.copyWith(isSaving: false);
    }
  }

  Future<void> deleteSelectedAttendance() async {
    if (state.isSaving) return;
    final classEntry = state.activeClass;
    final selectedDate = state.selectedDate;
    final sessionType = state.sessionType;
    if (classEntry == null || selectedDate == null) return;

    state = state.copyWith(isSaving: true);
    try {
      final box = Hive.box<SnapshotEntry>(HiveConstants.snapshotBox);
      final keys = <dynamic>[];
      for (final key in box.keys) {
        final snapshot = box.get(key)!;
        if (snapshot.classId == classEntry.classId &&
            snapshot.effectiveSessionType == sessionType &&
            isSameDate(snapshot.effectiveAttendanceDate, selectedDate)) {
          keys.add(key);
        }
      }
      await box.deleteAll(keys);
      if (keys.isNotEmpty) await BackupReminder.recordDataChange();
      if (mounted) _loadDateForClass(classEntry, selectedDate, sessionType);
    } finally {
      if (mounted) state = state.copyWith(isSaving: false);
    }
  }

  void reset() {
    state = const AttendanceGridState();
  }
}

final attendanceGridNotifier =
    StateNotifierProvider.autoDispose<
      AttendanceGridNotifier,
      AttendanceGridState
    >((ref) => AttendanceGridNotifier());
