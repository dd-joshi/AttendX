import 'dart:io';

import 'package:attendx/data/models/snapshot_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Writes the historical on-disk schema, including the retired fields.
class _LegacyAdapter extends SnapshotEntryAdapter {
  @override
  void write(BinaryWriter writer, SnapshotEntry obj) {
    final fields = <int, dynamic>{
      0: obj.snapshotId,
      1: obj.timestamp,
      2: obj.classId,
      3: obj.classTitle,
      4: obj.snapshotData,
      5: obj.attendanceDate,
      6: obj.sessionType,
      7: 'Legacy faculty',
      8: DateTime(2026, 10, 1),
      9: obj.topic,
    };
    writer.writeByte(fields.length);
    for (final field in fields.entries) {
      writer
        ..writeByte(field.key)
        ..write(field.value);
    }
  }
}

void main() {
  test(
    'existing Hive file opens, updates and reopens with retired fields',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'attendx_legacy_',
      );
      Hive.init(directory.path);
      addTearDown(() async {
        await Hive.close();
        await directory.delete(recursive: true);
      });
      Hive.registerAdapter<SnapshotEntry>(_LegacyAdapter(), override: true);
      var box = await Hive.openBox<SnapshotEntry>('legacy');
      await box.add(
        SnapshotEntry(
          snapshotId: 'old',
          timestamp: DateTime(2026, 9, 1),
          classId: 'old-class-code',
          classTitle: 'Physics',
          topic: 'ऊर्जा',
          snapshotData: [
            {'roll': '01', 'name': 'अदिती', 'isAbsent': true},
          ],
        ),
      );
      await box.close();
      Hive.registerAdapter<SnapshotEntry>(
        SnapshotEntryAdapter(),
        override: true,
      );
      box = await Hive.openBox<SnapshotEntry>('legacy');
      expect(box.values.single.topic, 'ऊर्जा');
      expect(box.values.single.snapshotData.single['isAbsent'], isTrue);
      box.values.single.topic = 'Updated';
      await box.values.single.save();
      await box.close();
      box = await Hive.openBox<SnapshotEntry>('legacy');
      expect(box.values.single.topic, 'Updated');
      expect(box.values.single.classId, 'old-class-code');
    },
  );
}
