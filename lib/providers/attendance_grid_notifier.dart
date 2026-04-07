import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/hive_constants.dart';
import '../data/models/class_entry.dart';
import '../data/models/snapshot_entry.dart';

class AttendanceGridState {
  const AttendanceGridState({
    this.activeClass,
    this.absentRolls = const <int>{},
    this.editingSnapshotId,
    this.isSaving = false,
  });

  final ClassEntry? activeClass;
  final Set<int> absentRolls;
  final String? editingSnapshotId;
  final bool isSaving;

  AttendanceGridState copyWith({
    ClassEntry? activeClass,
    Set<int>? absentRolls,
    String? editingSnapshotId,
    bool? isSaving,
    bool clearClass = false,
    bool clearEditingSnapshotId = false,
  }) {
    return AttendanceGridState(
      activeClass: clearClass ? null : (activeClass ?? this.activeClass),
      absentRolls: absentRolls ?? this.absentRolls,
      editingSnapshotId: clearEditingSnapshotId
          ? null
          : (editingSnapshotId ?? this.editingSnapshotId),
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class AttendanceGridNotifier extends StateNotifier<AttendanceGridState> {
  AttendanceGridNotifier() : super(const AttendanceGridState());

  static const _uuid = Uuid();

  void loadClass(ClassEntry c, {SnapshotEntry? existingSnapshot}) {
    final absentRolls = <int>{};
    if (existingSnapshot != null) {
      for (final row in existingSnapshot.snapshotData) {
        if (row['isAbsent'] == true) {
          final roll = int.tryParse('${row['roll']}');
          if (roll != null) absentRolls.add(roll);
        }
      }
    }

    state = AttendanceGridState(
      activeClass: c,
      absentRolls: absentRolls,
      editingSnapshotId: existingSnapshot?.snapshotId,
    );
  }

  void toggleRoll(int roll) {
    final previous = state.absentRolls;
    final next = Set<int>.from(previous);
    if (next.contains(roll)) {
      next.remove(roll);
    } else {
      next.add(roll);
    }
    state = state.copyWith(absentRolls: next);
  }

  void markAllPresent() {
    state = state.copyWith(absentRolls: <int>{});
  }

  void markAllAbsent() {
    final allRolls = Set<int>.from(
      List.generate(state.activeClass!.totalStudents, (i) => i + 1),
    );
    state = state.copyWith(absentRolls: allRolls);
  }

  Future<void> saveSnapshot() async {
    final c = state.activeClass;
    if (c == null) return;

    state = state.copyWith(isSaving: true);
    try {
      final data = <Map<String, dynamic>>[];
      for (var roll = 1; roll <= c.totalStudents; roll++) {
        final rollStr = roll.toString().padLeft(2, '0');
        data.add(<String, dynamic>{
          'roll': rollStr,
          'name': c.students[rollStr] ?? '',
          'isAbsent': state.absentRolls.contains(roll),
        });
      }

      final entry = SnapshotEntry(
        snapshotId: _uuid.v4(),
        timestamp: DateTime.now(),
        classId: c.classId,
        classTitle: c.title,
        snapshotData: data,
      );

      final box = Hive.box<SnapshotEntry>(HiveConstants.snapshotBox);
      final editingSnapshotId = state.editingSnapshotId;
      if (editingSnapshotId != null) {
        dynamic snapshotBoxKeyToDelete;
        for (final entry in box.toMap().entries) {
          if (entry.value.snapshotId == editingSnapshotId) {
            snapshotBoxKeyToDelete = entry.key;
            break;
          }
        }
        if (snapshotBoxKeyToDelete != null) {
          await box.delete(snapshotBoxKeyToDelete);
        }
      }
      await box.add(entry);
      state = state.copyWith(clearEditingSnapshotId: true);
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  void reset() {
    state = const AttendanceGridState();
  }
}

final attendanceGridNotifier =
    StateNotifierProvider<AttendanceGridNotifier, AttendanceGridState>(
  (ref) => AttendanceGridNotifier(),
);
