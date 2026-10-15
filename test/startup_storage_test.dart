import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:attendx/core/hive_constants.dart';
import 'package:attendx/core/snapshot_storage.dart';
import 'package:attendx/data/models/class_entry.dart';
import 'package:attendx/data/models/snapshot_entry.dart';
import 'package:attendx/screens/dashboard_screen.dart';

void main() {
  late Directory hiveDirectory;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('attendx_startup_');
    Hive.init(hiveDirectory.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ClassEntryAdapter());
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(SnapshotEntryAdapter());
    }
    await Hive.openBox<ClassEntry>(HiveConstants.classBox);
  });

  tearDown(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test(
    'attendance history can open concurrently after dashboard data',
    () async {
      expect(Hive.isBoxOpen(HiveConstants.snapshotBox), isFalse);
      final first = openSnapshotBox();
      final second = openSnapshotBox();
      expect(identical(first, second), isTrue);
      final boxes = await Future.wait([first, second]);
      expect(identical(boxes[0], boxes[1]), isTrue);
    },
  );

  testWidgets('dashboard shows cached classes immediately and updates', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    expect(find.text('Create your first class'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.runAsync(
      () => Hive.box<ClassEntry>(HiveConstants.classBox).put(
        'physics',
        ClassEntry(
          classId: 'physics',
          title: 'Physics',
          weekdays: const [0],
          startHour: 9,
          totalStudents: 0,
          students: const {},
        ),
      ),
    );
    await tester.pump();
    // The class may appear both under "Now / Upcoming" (when it is within
    // two hours of its scheduled start) and under "All classes", so accept
    // one or more tiles instead of exactly one.
    expect(find.text('Physics'), findsWidgets);
  });
}
