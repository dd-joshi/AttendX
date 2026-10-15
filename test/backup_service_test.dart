import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendx/core/hive_constants.dart';
import 'package:attendx/data/backup_service.dart';
import 'package:attendx/data/models/class_entry.dart';
import 'package:attendx/data/models/snapshot_entry.dart';

void main() {
  late Directory hiveDirectory;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'attendx_backup_test_',
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

  Future<void> seedData() async {
    final classEntry = ClassEntry(
      classId: 'se-comp-a',
      title: 'SE COMP A',
      weekdays: const [1, 3],
      startHour: 9,
      totalStudents: 2,
      students: const {'01': 'Student One', '02': 'Student Two'},
      studentAddedOn: {'02': DateTime(2026, 8, 15)},
    );
    await Hive.box<ClassEntry>(HiveConstants.classBox)
        .put(classEntry.classId, classEntry);

    final snapshot = SnapshotEntry(
      snapshotId: 'snap-1',
      timestamp: DateTime(2026, 9, 30, 10, 5),
      attendanceDate: DateTime(2026, 9, 30),
      sessionType: SessionTypes.lab,
      classId: 'se-comp-a',
      classTitle: 'SE COMP A',
      snapshotData: const [
        {'roll': '01', 'name': 'Student One', 'isAbsent': false},
        {'roll': '02', 'name': 'Student Two', 'isAbsent': true},
      ],
    );
    await Hive.box<SnapshotEntry>(HiveConstants.snapshotBox).add(snapshot);
  }

  test(
    'backup round-trip restores classes and attendance after a wipe',
    () async {
      await seedData();
      final json = BackupService.buildBackupJson();

      // Simulate the wipe an uninstall/reinstall causes.
      await Hive.box<ClassEntry>(HiveConstants.classBox).clear();
      await Hive.box<SnapshotEntry>(HiveConstants.snapshotBox).clear();
      expect(Hive.box<ClassEntry>(HiveConstants.classBox), isEmpty);
      expect(Hive.box<SnapshotEntry>(HiveConstants.snapshotBox), isEmpty);

      final result = await BackupService.restoreFromJson(json);
      expect(result.classes, 1);
      expect(result.snapshots, 1);

      final restored = Hive.box<ClassEntry>(HiveConstants.classBox)
          .get('se-comp-a')!;
      expect(restored.title, 'SE COMP A');
      expect(restored.students, {'01': 'Student One', '02': 'Student Two'});
      expect(restored.studentAddedOn?['02'], DateTime(2026, 8, 15));

      final restoredSnapshot = Hive.box<SnapshotEntry>(
        HiveConstants.snapshotBox,
      ).values.single;
      expect(restoredSnapshot.snapshotId, 'snap-1');
      expect(restoredSnapshot.effectiveSessionType, SessionTypes.lab);
      expect(restoredSnapshot.effectiveAttendanceDate, DateTime(2026, 9, 30));
      expect(restoredSnapshot.snapshotData, const [
        {'roll': '01', 'name': 'Student One', 'isAbsent': false},
        {'roll': '02', 'name': 'Student Two', 'isAbsent': true},
      ]);
    },
  );

  test('restoring merges and replaces records with the same ids', () async {
    await seedData();
    final json = BackupService.buildBackupJson();

    await Hive.box<SnapshotEntry>(HiveConstants.snapshotBox).clear();
    await seedData();

    final result = await BackupService.restoreFromJson(json);
    expect(result.classes, 1);
    expect(result.snapshots, 1);
    expect(Hive.box<ClassEntry>(HiveConstants.classBox).values.length, 1);
    expect(Hive.box<SnapshotEntry>(HiveConstants.snapshotBox).values.length, 1);
  });

  test('restore rejects files that are not AttendX backups', () async {
    await expectLater(
      BackupService.restoreFromJson('not json at all'),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'invalid later attendance does not overwrite an earlier valid class',
    () async {
      await seedData();
      final data = jsonDecode(BackupService.buildBackupJson());
      data['classes'][0]['title'] = 'Must not replace local title';
      data['snapshots'][0]['timestamp'] = 'broken';
      await expectLater(
        BackupService.restoreFromJson(jsonEncode(data)),
        throwsFormatException,
      );
      expect(
        Hive.box<ClassEntry>(HiveConstants.classBox).get('se-comp-a')!.title,
        'SE COMP A',
      );
      expect(Hive.box<SnapshotEntry>(HiveConstants.snapshotBox).length, 1);
    },
  );

  test(
    'duplicate IDs, invalid schedules and unsupported versions are rejected',
    () async {
      await seedData();
      final original = BackupService.buildBackupJson();
      for (final corrupt in <void Function(dynamic)>[
        (data) => data['snapshots'].add(data['snapshots'][0]),
        (data) => data['classes'][0]['startHour'] = 25,
        (data) => data['classes'][0]['weekdays'] = [9],
        (data) => data['backupVersion'] = 0,
        (data) => data['snapshots'][0]['snapshotData'][0]['isAbsent'] = 'false',
        (data) => data['snapshots'][0]['classId'] = 'missing-class',
      ]) {
        final data = jsonDecode(original);
        corrupt(data);
        await expectLater(
          BackupService.restoreFromJson(jsonEncode(data)),
          throwsFormatException,
        );
        expect(Hive.box<ClassEntry>(HiveConstants.classBox).length, 1);
        expect(Hive.box<SnapshotEntry>(HiveConstants.snapshotBox).length, 1);
      }
    },
  );

  test(
    'older optional fields remain compatible and Unicode survives restore',
    () async {
      await seedData();
      final data = jsonDecode(BackupService.buildBackupJson());
      data['classes'][0]['students']['01'] = 'अदिती जोशी';
      final snapshot = data['snapshots'][0];
      snapshot['snapshotData'][0]['name'] = 'अदिती जोशी';
      snapshot['topic'] = 'ऊर्जा — परीक्षण';
      snapshot['facultyId'] = 'Legacy faculty';
      snapshot['updatedAt'] = '2026-10-01T10:00:00.000';
      await BackupService.restoreFromJson(
        utf8.decode(utf8.encode(jsonEncode(data))),
      );
      final restored = Hive.box<SnapshotEntry>(HiveConstants.snapshotBox)
          .values
          .single;
      expect(restored.snapshotData[0]['name'], 'अदिती जोशी');
      expect(restored.topic, 'ऊर्जा — परीक्षण');
      final newData = jsonDecode(BackupService.buildBackupJson());
      expect(newData['snapshots'][0].containsKey('facultyId'), isFalse);
    },
  );
}
