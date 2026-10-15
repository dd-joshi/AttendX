import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendx/core/hive_constants.dart';
import 'package:attendx/data/backup_reminder.dart';
import 'package:attendx/data/class_roster_service.dart';
import 'package:attendx/data/class_schedule.dart';
import 'package:attendx/data/delete_class_data.dart';
import 'package:attendx/data/models/class_entry.dart';
import 'package:attendx/data/models/snapshot_entry.dart';
import 'package:attendx/export/build_csv_matrix.dart';
import 'package:attendx/providers/attendance_grid_notifier.dart';
import 'package:attendx/providers/export_filter_notifier.dart';
import 'package:attendx/providers/roster_ingestion_notifier.dart';
import 'package:attendx/screens/attendance_grid_screen.dart';
import 'package:attendx/widgets/student_name_edit_dialog.dart';

void main() {
  late Directory hiveDirectory;

  ClassEntry classEntry({
    int totalStudents = 2,
    Map<String, DateTime>? studentAddedOn,
  }) {
    return ClassEntry(
      classId: 'class-1',
      title: 'Class A',
      weekdays: const [0],
      startHour: 9,
      totalStudents: totalStudents,
      students: {
        '01': 'Student One',
        if (totalStudents > 1) '02': 'Student Two',
      },
      studentAddedOn: studentAddedOn,
    );
  }

  SnapshotEntry snapshot({
    required String id,
    required DateTime createdAt,
    DateTime? attendanceDate,
    Set<int> absentRolls = const {},
  }) {
    return SnapshotEntry(
      snapshotId: id,
      timestamp: createdAt,
      attendanceDate: attendanceDate,
      classId: 'class-1',
      classTitle: 'Class A',
      snapshotData: [
        {
          'roll': '01',
          'name': 'Student One',
          'isAbsent': absentRolls.contains(1),
        },
        {
          'roll': '02',
          'name': 'Student Two',
          'isAbsent': absentRolls.contains(2),
        },
      ],
    );
  }

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('attendx_test_');
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

  test('older records use their creation timestamp as attendance date', () {
    final olderRecord = snapshot(
      id: 'old',
      createdAt: DateTime(2025, 7, 4, 14, 30),
    );

    expect(olderRecord.effectiveAttendanceDate, DateTime(2025, 7, 4));
  });

  test('classes are ordered by their next scheduled occurrence', () {
    ClassEntry scheduledClass(
      String id,
      String title,
      List<int> weekdays,
      int startHour,
    ) {
      return ClassEntry(
        classId: id,
        title: title,
        weekdays: weekdays,
        startHour: startHour,
        totalStudents: 0,
        students: const {},
      );
    }

    final now = DateTime(2026, 8, 10, 10, 45); // Monday.
    final ordered = sortClassesByNextOccurrence([
      scheduledClass('passed', 'Passed Today', const [0], 9),
      scheduledClass('tomorrow', 'Tomorrow', const [1], 8),
      scheduledClass('unscheduled', 'Unscheduled', const [], 12),
      scheduledClass('later', 'Later Today', const [0], 11),
      scheduledClass('current', 'Current Hour', const [0], 10),
    ], now);

    expect(ordered.map((entry) => entry.classId), [
      'current',
      'later',
      'tomorrow',
      'passed',
      'unscheduled',
    ]);
  });

  testWidgets('number grid long press reveals the student name', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 80,
                height: 80,
                child: AttendanceCell(
                  student: AttendanceStudent(roll: 1, name: 'Student One'),
                  showName: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('01'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Student One'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    final tooltipRect = tester.getRect(find.text('Student One'));
    final numberRect = tester.getRect(find.text('01'));
    expect(tooltipRect.bottom, lessThan(numberRect.top));

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('attendance cell exposes an actionable screen-reader button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(attendanceGridNotifier.notifier).loadClass(classEntry());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 60,
              child: AttendanceCell(
                student: AttendanceStudent(roll: 1, name: 'Student One'),
                showName: true,
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(AttendanceCell)),
      matchesSemantics(
        label: 'Roll 01, Student One, Present',
        hint: 'Tap to mark absent. Long press to edit name.',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        hasLongPressAction: true,
      ),
    );
    await tester.tap(find.text('Student One'));
    await tester.pumpAndSettle();
    expect(container.read(attendanceGridNotifier).absentRolls, {1});
    semantics.dispose();
  });

  testWidgets('student name dialog tears down safely after save', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => const StudentNameEditDialog(
                    rollLabel: '01',
                    initialName: 'Old Name',
                  ),
                );
              },
              child: const Text('Edit student'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit student'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'Corrected Name');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(result, 'Corrected Name');
    expect(tester.takeException(), isNull);
  });

  test('roster save can finish after its notifier is disposed', () async {
    final entry = ClassEntry(
      classId: 'dispose-roster',
      title: 'Dispose Roster',
      weekdays: const [0],
      startHour: 9,
      totalStudents: 0,
      students: <String, String>{},
    );
    await Hive.box<ClassEntry>(HiveConstants.classBox)
        .put(entry.classId, entry);

    final notifier = RosterIngestionNotifier(entry)..parsePaste('Student One');
    final saving = notifier.confirmAndSave();
    notifier.dispose();

    await expectLater(saving, completes);
    expect(
      Hive.box<ClassEntry>(HiveConstants.classBox)
          .get(entry.classId)!
          .students['01'],
      'Student One',
    );
  });

  test('attendance save can finish after its notifier is disposed', () async {
    final entry = classEntry();
    await Hive.box<ClassEntry>(HiveConstants.classBox)
        .put(entry.classId, entry);

    final notifier = AttendanceGridNotifier()..loadClass(entry);
    notifier.toggleRoll(2);
    final saving = notifier.saveAttendance();
    notifier.dispose();

    await expectLater(saving, completes);
    expect(
      Hive.box<SnapshotEntry>(HiveConstants.snapshotBox).values,
      hasLength(1),
    );
  });

  test('roster parser preserves real names, punctuation, and duplicates', () {
    final names = parseRosterNames(
      "  Zoë O'Neil  \r\nJean-Luc   Picard\nZoë O'Neil\n\n",
    );

    expect(names, ["Zoë O'Neil", 'Jean-Luc Picard', "Zoë O'Neil"]);
  });

  test('initial roster is active for every date', () async {
    final entry = ClassEntry(
      classId: 'empty-class',
      title: 'New Class',
      weekdays: const [0],
      startHour: 9,
      totalStudents: 0,
      students: <String, String>{},
    );
    await Hive.box<ClassEntry>(HiveConstants.classBox)
        .put(entry.classId, entry);
    final notifier = RosterIngestionNotifier(entry)
      ..parsePaste('Student One\nStudent Two');
    addTearDown(notifier.dispose);

    final saved = await notifier.confirmAndSave(now: DateTime(2026, 8, 9));

    expect(saved.totalStudents, 2);
    expect(saved.studentAddedOn, isNull);
    expect(activeRollsForDate(saved, DateTime(2020, 1, 1)), [1, 2]);
  });

  test('roster update only appends and dates new admissions', () async {
    final entry = classEntry();
    await Hive.box<ClassEntry>(HiveConstants.classBox)
        .put(entry.classId, entry);
    final notifier = RosterIngestionNotifier(entry)
      ..parsePaste('Student One\nStudent Two\nStudent Three');
    addTearDown(notifier.dispose);

    final saved = await notifier.confirmAndSave(now: DateTime(2026, 8, 9, 14));

    expect(saved.students['03'], 'Student Three');
    expect(saved.studentAddedOn?['03'], DateTime(2026, 8, 9));
    expect(activeRollsForDate(saved, DateTime(2026, 8, 8)), [1, 2]);
    expect(activeRollsForDate(saved, DateTime(2026, 8, 9)), [1, 2, 3]);
  });

  test('roster update blocks reordering or replacing existing students', () {
    final notifier = RosterIngestionNotifier(classEntry())
      ..parsePaste('Student Two\nStudent One\nStudent Three');
    addTearDown(notifier.dispose);

    expect(notifier.state.canSave, isFalse);
    expect(notifier.state.errorMessage, contains('order must stay unchanged'));
  });

  test('editing pasted text invalidates an older roster preview', () {
    final notifier = RosterIngestionNotifier(classEntry())
      ..parsePaste('Student One\nStudent Two\nStudent Three');
    addTearDown(notifier.dispose);

    expect(notifier.state.canSave, isTrue);
    notifier.invalidatePreview();
    expect(notifier.state.canSave, isFalse);
    expect(notifier.state.hasParsed, isFalse);
  });

  test('new attendance uses the roster active on its selected date', () async {
    final entry = ClassEntry(
      classId: 'class-1',
      title: 'Class A',
      weekdays: const [0],
      startHour: 9,
      totalStudents: 3,
      students: const {
        '01': 'Student One',
        '02': 'Student Two',
        '03': 'Student Three',
      },
      studentAddedOn: {'03': DateTime(2026, 8, 9)},
    );
    await Hive.box<ClassEntry>(HiveConstants.classBox)
        .put(entry.classId, entry);
    final notifier = AttendanceGridNotifier()
      ..loadClass(entry, initialDate: DateTime(2026, 8, 8));
    addTearDown(notifier.dispose);

    expect(notifier.state.roster.map((student) => student.roll), [1, 2]);

    notifier.selectDate(DateTime(2026, 8, 9));
    expect(notifier.state.roster.map((student) => student.roll), [1, 2, 3]);
  });

  test('existing attendance keeps exactly its saved roster', () async {
    final entry = ClassEntry(
      classId: 'class-1',
      title: 'Class A',
      weekdays: const [0],
      startHour: 9,
      totalStudents: 3,
      students: const {
        '01': 'Student One',
        '02': 'Student Two',
        '03': 'Student Three',
      },
      studentAddedOn: {'03': DateTime(2026, 8, 9)},
    );
    await Hive.box<ClassEntry>(HiveConstants.classBox)
        .put(entry.classId, entry);
    await Hive.box<SnapshotEntry>(HiveConstants.snapshotBox).add(
      SnapshotEntry(
        snapshotId: 'older-session',
        timestamp: DateTime(2026, 8, 9, 10),
        attendanceDate: DateTime(2026, 8, 8),
        classId: entry.classId,
        classTitle: entry.title,
        snapshotData: const [
          {'roll': '01', 'name': 'Student One', 'isAbsent': false},
        ],
      ),
    );
    final notifier = AttendanceGridNotifier()
      ..loadClass(entry, initialDate: DateTime(2026, 8, 8));
    addTearDown(notifier.dispose);

    expect(notifier.state.hasExistingAttendance, isTrue);
    expect(notifier.state.roster.map((student) => student.roll), [1]);
  });

  test('new attendance saves the selected back date', () async {
    final entry = classEntry();
    await Hive.box<ClassEntry>(HiveConstants.classBox)
        .put(entry.classId, entry);
    final notifier = AttendanceGridNotifier()
      ..loadClass(entry, initialDate: DateTime(2026, 7, 10));
    addTearDown(notifier.dispose);

    notifier.toggleRoll(2);
    final result = await notifier.saveAttendance();
    final saved = Hive.box<SnapshotEntry>(HiveConstants.snapshotBox)
        .values
        .single;

    expect(result, AttendanceSaveResult.created);
    expect(saved.attendanceDate, DateTime(2026, 7, 10));
    expect(saved.snapshotData[1]['isAbsent'], isTrue);
    expect(notifier.state.hasExistingAttendance, isTrue);
    expect(notifier.state.isDirty, isFalse);
  });

  test('existing attendance loads by date and updates in place', () async {
    final entry = classEntry();
    await Hive.box<ClassEntry>(HiveConstants.classBox)
        .put(entry.classId, entry);
    final createdAt = DateTime(2026, 8, 9, 10, 1);
    await Hive.box<SnapshotEntry>(HiveConstants.snapshotBox).add(
      snapshot(
        id: 'saved-id',
        createdAt: createdAt,
        attendanceDate: DateTime(2026, 8, 8),
        absentRolls: {1},
      ),
    );

    final notifier = AttendanceGridNotifier()
      ..loadClass(entry, initialDate: DateTime(2026, 8, 8));
    addTearDown(notifier.dispose);

    expect(notifier.state.editingSnapshotId, 'saved-id');
    expect(notifier.state.absentRolls, {1});

    notifier.toggleRoll(2);
    expect(notifier.state.isDirty, isTrue);
    final result = await notifier.saveAttendance();
    final saved = Hive.box<SnapshotEntry>(HiveConstants.snapshotBox)
        .values
        .single;

    expect(result, AttendanceSaveResult.updated);
    expect(saved.snapshotId, 'saved-id');
    expect(saved.timestamp, createdAt);
    expect(saved.attendanceDate, DateTime(2026, 8, 8));
    expect(saved.snapshotData[0]['isAbsent'], isTrue);
    expect(saved.snapshotData[1]['isAbsent'], isTrue);
    expect(notifier.state.isDirty, isFalse);
  });

  test('all-present changes are tracked for new and existing dates', () async {
    final entry = classEntry();
    await Hive.box<ClassEntry>(HiveConstants.classBox)
        .put(entry.classId, entry);
    await Hive.box<SnapshotEntry>(HiveConstants.snapshotBox).add(
      snapshot(
        id: 'saved-id',
        createdAt: DateTime(2026, 8, 9, 10),
        attendanceDate: DateTime(2026, 8, 8),
        absentRolls: {1},
      ),
    );
    final notifier = AttendanceGridNotifier()
      ..loadClass(entry, initialDate: DateTime(2026, 8, 8));
    addTearDown(notifier.dispose);

    notifier.markAllPresent();
    expect(notifier.state.isDirty, isTrue);

    notifier.selectDate(DateTime(2026, 8, 7));
    notifier.markAllPresent();
    expect(notifier.state.hasExistingAttendance, isFalse);
    expect(notifier.state.isDirty, isTrue);
  });

  test(
    'newest legacy duplicate is loaded and date deletion removes all',
    () async {
      final entry = classEntry();
      await Hive.box<ClassEntry>(HiveConstants.classBox)
          .put(entry.classId, entry);
      final box = Hive.box<SnapshotEntry>(HiveConstants.snapshotBox);
      await box.add(
        snapshot(
          id: 'older',
          createdAt: DateTime(2026, 8, 8, 9),
          attendanceDate: DateTime(2026, 8, 7),
          absentRolls: {1},
        ),
      );
      await box.add(
        snapshot(
          id: 'newer',
          createdAt: DateTime(2026, 8, 8, 10),
          attendanceDate: DateTime(2026, 8, 7),
          absentRolls: {2},
        ),
      );
      final notifier = AttendanceGridNotifier()
        ..loadClass(entry, initialDate: DateTime(2026, 8, 7));
      addTearDown(notifier.dispose);

      expect(notifier.state.editingSnapshotId, 'newer');
      expect(notifier.state.absentRolls, {2});

      await notifier.deleteSelectedAttendance();
      expect(box.values, isEmpty);
      expect(notifier.state.hasExistingAttendance, isFalse);
      expect(notifier.state.selectedDate, DateTime(2026, 8, 7));
    },
  );

  test('editing a name updates the roster and all saved attendance', () async {
    final entry = classEntry();
    await Hive.box<ClassEntry>(HiveConstants.classBox)
        .put(entry.classId, entry);
    await Hive.box<SnapshotEntry>(HiveConstants.snapshotBox)
        .add(snapshot(id: 'snapshot-1', createdAt: DateTime(2026, 8, 9)));
    final notifier = AttendanceGridNotifier()..loadClass(entry);
    addTearDown(notifier.dispose);

    await notifier.updateStudentName(roll: 1, name: '  New Name  ');

    final savedClass = Hive.box<ClassEntry>(HiveConstants.classBox)
        .get(entry.classId);
    final savedSnapshot = Hive.box<SnapshotEntry>(HiveConstants.snapshotBox)
        .values
        .single;
    expect(savedClass?.students['01'], 'New Name');
    expect(savedSnapshot.snapshotData.first['name'], 'New Name');
  });

  test('deleting a class removes its attendance and view preference', () async {
    final entry = classEntry();
    await Hive.box<ClassEntry>(HiveConstants.classBox)
        .put(entry.classId, entry);
    await Hive.box<SnapshotEntry>(HiveConstants.snapshotBox)
        .add(snapshot(id: 'snapshot-1', createdAt: DateTime(2026, 8, 9)));
    await Hive.box<dynamic>(HiveConstants.settingsBox)
        .put('attendance_name_cards_${entry.classId}', false);

    await deleteClassData(entry);

    expect(Hive.box<ClassEntry>(HiveConstants.classBox).values, isEmpty);
    expect(Hive.box<SnapshotEntry>(HiveConstants.snapshotBox).values, isEmpty);
    final settings = Hive.box<dynamic>(HiveConstants.settingsBox);
    expect(
      settings.containsKey('attendance_name_cards_${entry.classId}'),
      isFalse,
    );
    expect(settings.get(BackupReminder.savesSinceBackupKey), greaterThan(0));
  });

  test('CSV uses attendance date and escapes corrected names', () {
    final csv = buildCsvMatrix([
      {
        'timestamp': DateTime(2026, 8, 9, 10),
        'attendanceDate': DateTime(2026, 7, 10),
        'snapshotData': [
          {'roll': '01', 'name': 'Doe, "Jane"', 'isAbsent': false},
        ],
      },
    ]);

    expect(csv, contains('2026-07-10'));
    expect(csv, isNot(contains('2026-08-09')));
    expect(csv, contains('"Doe, ""Jane"""'));
  });

  test('CSV lists the topic of each session under its date column', () {
    final csv = buildCsvMatrix([
      {
        'timestamp': DateTime(2026, 1, 10, 10),
        'attendanceDate': DateTime(2026, 1, 10),
        'topic': 'Unit 1 \u2014 Ohm\'s law',
        'snapshotData': [
          {'roll': '01', 'name': 'Student One', 'isAbsent': false},
        ],
      },
      {
        'timestamp': DateTime(2026, 1, 11, 10),
        'attendanceDate': DateTime(2026, 1, 11),
        'sessionType': 'lab',
        'topic': 'Lab: resistors',
        'snapshotData': [
          {'roll': '01', 'name': 'Student One', 'isAbsent': true},
        ],
      },
      {
        'timestamp': DateTime(2026, 1, 12, 10),
        'attendanceDate': DateTime(2026, 1, 12),
        'snapshotData': [
          {'roll': '01', 'name': 'Student One', 'isAbsent': false},
        ],
      },
    ]);

    final lines = csv.trim().split('\n');
    expect(
      lines[0],
      startsWith('Roll,Name,2026-01-10,2026-01-11 Lab,2026-01-12'),
    );
    expect(lines[1], "Topic,,Unit 1 \u2014 Ohm's law,Lab: resistors,");
    expect(lines[2], startsWith('01,Student One,P,A,P'));
  });

  test('semester CSV unions X, Y, and Z rosters across saved sessions', () {
    final csv = buildCsvMatrix([
      {
        'timestamp': DateTime(2026, 1, 10, 10),
        'attendanceDate': DateTime(2026, 1, 10),
        'snapshotData': [
          {'roll': '01', 'name': 'Student One', 'isAbsent': false},
          {'roll': '02', 'name': 'Student Two', 'isAbsent': true},
        ],
      },
      {
        'timestamp': DateTime(2026, 2, 10, 10),
        'attendanceDate': DateTime(2026, 2, 10),
        'snapshotData': [
          {'roll': '01', 'name': 'Student One', 'isAbsent': false},
          {'roll': '02', 'name': 'Student Two', 'isAbsent': false},
          {'roll': '03', 'name': 'Student Three', 'isAbsent': false},
        ],
      },
      {
        'timestamp': DateTime(2026, 3, 10, 10),
        'attendanceDate': DateTime(2026, 3, 10),
        'snapshotData': [
          {'roll': '01', 'name': 'Student One', 'isAbsent': false},
          {'roll': '02', 'name': 'Student Two', 'isAbsent': false},
          {'roll': '03', 'name': 'Student Three', 'isAbsent': true},
          {'roll': '04', 'name': 'Student Four', 'isAbsent': false},
        ],
      },
    ]);

    expect(csv, startsWith('Roll,Name,2026-01-10,2026-02-10,2026-03-10'));
    expect(csv, contains('03,Student Three,-,P,A'));
    expect(csv, contains('04,Student Four,-,-,P'));
  });

  test('export requires a class and a valid date range', () async {
    final notifier = ExportFilterNotifier();
    addTearDown(notifier.dispose);

    await notifier.runExport();
    expect(notifier.state.exportError, 'Select a class');

    notifier.setClass('class-1');
    notifier.setFromDate(DateTime(2026, 8, 9));
    notifier.setToDate(DateTime(2026, 8, 8));
    await notifier.runExport();
    expect(
      notifier.state.exportError,
      'From date must be before or equal to To date',
    );
  });
}
