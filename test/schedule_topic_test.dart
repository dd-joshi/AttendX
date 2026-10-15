import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendx/core/hive_constants.dart';
import 'package:attendx/data/class_schedule.dart';
import 'package:attendx/data/models/class_entry.dart';
import 'package:attendx/data/models/snapshot_entry.dart';
import 'package:attendx/providers/attendance_grid_notifier.dart';

void main() {
  test('each weekday can start at a different hour', () {
    final entry = ClassEntry(
      classId: 'c1',
      title: 'Test',
      weekdays: const [1, 4], // Tuesday, Friday
      startHour: 9,
      weekdayHours: const {'1': 9, '4': 13},
      totalStudents: 0,
      students: const {},
    );

    // From Wednesday 30 Sep 2026 noon (weekday 2 in Mon..Sun = 0..6):
    // Tuesday 9:00 lands on 6 Oct, Friday 13:00 lands on 2 Oct — so the
    // next occurrence is Friday 2 Oct at 13:00.
    final next = nextClassOccurrence(entry, DateTime(2026, 9, 30, 12));
    expect(next, DateTime(2026, 10, 2, 13));
    expect(entry.hourForWeekday(1), 9);
    expect(entry.hourForWeekday(4), 13);
  });

  test('older classes without weekdayHours use the single start hour', () {
    final entry = ClassEntry(
      classId: 'c2',
      title: 'Legacy',
      weekdays: const [1, 4],
      startHour: 10,
      totalStudents: 0,
      students: const {},
    );
    expect(entry.hourForWeekday(1), 10);
    expect(entry.hourForWeekday(4), 10);
    expect(
      nextClassOccurrence(entry, DateTime(2026, 9, 30, 12)),
      DateTime(2026, 10, 2, 10),
    );
  });

  group('attendance records', () {
    late Directory hiveDirectory;

    setUp(() async {
      hiveDirectory = await Directory.systemTemp.createTemp(
        'attendx_topic_test_',
      );
      Hive.init(hiveDirectory.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(ClassEntryAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(SnapshotEntryAdapter());
      }
      await Hive.openBox<ClassEntry>(HiveConstants.classBox);
      await Hive.openBox<SnapshotEntry>(HiveConstants.snapshotBox);
      await Hive.openBox<dynamic>(HiveConstants.settingsBox);
    });

    tearDown(() async {
      await Hive.close();
      await hiveDirectory.delete(recursive: true);
    });

    test('is saved with the attendance record and loaded back', () async {
      final entry = ClassEntry(
        classId: 'class-1',
        title: 'Test',
        weekdays: const [1],
        startHour: 9,
        totalStudents: 1,
        students: const {'01': 'Student One'},
      );
      await Hive.box<ClassEntry>(HiveConstants.classBox)
          .put(entry.classId, entry);

      final notifier = AttendanceGridNotifier()..loadClass(entry);
      notifier.setTopic('Unit 2 \u2014 Transformers');
      final result = await notifier.saveAttendance();
      expect(result, AttendanceSaveResult.created);

      final saved = Hive.box<SnapshotEntry>(HiveConstants.snapshotBox)
          .values
          .single;
      expect(saved.topic, 'Unit 2 \u2014 Transformers');

      final reloaded = AttendanceGridNotifier()..loadClass(entry);
      expect(reloaded.state.topic, 'Unit 2 \u2014 Transformers');
      expect(reloaded.state.isDirty, isFalse);
    });

    test('a Lab class always records lab sessions', () async {
      final entry = ClassEntry(
        classId: 'lab-1',
        title: 'Test Lab',
        weekdays: const [2],
        startHour: 14,
        classType: ClassTypes.lab,
        totalStudents: 1,
        students: const {'01': 'Student One'},
      );
      await Hive.box<ClassEntry>(HiveConstants.classBox)
          .put(entry.classId, entry);

      final notifier = AttendanceGridNotifier()..loadClass(entry);
      expect(notifier.state.sessionType, SessionTypes.lab);

      await notifier.saveAttendance();
      final saved = Hive.box<SnapshotEntry>(HiveConstants.snapshotBox)
          .values
          .single;
      expect(saved.effectiveSessionType, SessionTypes.lab);
    });

    test('classes without a recorded type count as lecture', () {
      final entry = ClassEntry(
        classId: 'old-1',
        title: 'Test',
        weekdays: const [1],
        startHour: 9,
        totalStudents: 1,
        students: const {'01': 'Student One'},
      );
      expect(entry.effectiveClassType, ClassTypes.lecture);

      final notifier = AttendanceGridNotifier()..loadClass(entry);
      expect(notifier.state.sessionType, SessionTypes.lecture);
    });
  });
}
