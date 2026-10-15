import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:attendx/core/hive_constants.dart';
import 'package:attendx/data/backup_reminder.dart';
import 'package:attendx/data/models/class_entry.dart';
import 'package:attendx/data/models/snapshot_entry.dart';
import 'package:attendx/widgets/backup_bottom_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _Picker extends FilePickerPlatform {
  Uri? destination;
  Uint8List? savedBytes;
  bool fail = false;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (fail) throw const FileSystemException('Cannot write');
    savedBytes = bytes;
    return destination;
  }
}

void main() {
  late Directory directory;
  late FilePickerPlatform originalPicker;
  late _Picker picker;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('attendx_backup_ui_');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ClassEntryAdapter());
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(SnapshotEntryAdapter());
    }
    await Hive.openBox<ClassEntry>(HiveConstants.classBox);
    await Hive.openBox<SnapshotEntry>(HiveConstants.snapshotBox);
    await Hive.openBox<dynamic>(HiveConstants.settingsBox);
    for (var i = 0; i < 5; i++) {
      await BackupReminder.recordDataChange();
    }
    originalPicker = FilePickerPlatform.instance;
    picker = _Picker();
    FilePickerPlatform.instance = picker;
  });

  tearDown(() async {
    FilePickerPlatform.instance = originalPicker;
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> save(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BackupBottomSheet())),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Save backup file'));
      await Hive.box<dynamic>(HiveConstants.settingsBox).flush();
    });
    await tester.pumpAndSettle();
  }

  testWidgets('cancelled save keeps the backup reminder due', (tester) async {
    await save(tester);
    expect(find.text('Backup cancelled. No file was saved.'), findsOneWidget);
    expect(BackupReminder.isDue(), isTrue);
  });

  testWidgets('confirmed file save writes valid UTF-8 and resets reminder', (
    tester,
  ) async {
    picker.destination = Uri.parse('content://documents/backup.json');
    await tester.runAsync(
      () => Hive.box<ClassEntry>(HiveConstants.classBox).put(
        'c1',
        ClassEntry(
          classId: 'c1',
          title: 'विद्युत',
          weekdays: [0],
          startHour: 9,
          totalStudents: 1,
          students: {'01': 'अदिती'},
        ),
      ),
    );
    await save(tester);
    expect(BackupReminder.isDue(), isFalse);
    final data = jsonDecode(utf8.decode(picker.savedBytes!));
    expect(data['classes'][0]['students']['01'], 'अदिती');
    expect(find.textContaining('Backup saved to'), findsOneWidget);
  });

  testWidgets('write failure keeps reminder and displays an error', (
    tester,
  ) async {
    picker.fail = true;
    await save(tester);
    expect(BackupReminder.isDue(), isTrue);
    expect(find.text('Could not create the backup file.'), findsOneWidget);
  });
}
