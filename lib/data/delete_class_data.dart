import 'package:hive_flutter/hive_flutter.dart';

import '../core/hive_constants.dart';
import '../core/snapshot_storage.dart';
import 'backup_reminder.dart';
import 'models/class_entry.dart';

Future<void> deleteClassData(ClassEntry classEntry) async {
  final snapshotBox = await openSnapshotBox();
  final snapshotKeys = <dynamic>[];
  for (final key in snapshotBox.keys) {
    final snapshot = snapshotBox.get(key);
    if (snapshot?.classId != classEntry.classId) continue;
    snapshotKeys.add(key);
  }

  await snapshotBox.deleteAll(snapshotKeys);
  await Hive.box<dynamic>(HiveConstants.settingsBox)
      .delete('attendance_name_cards_${classEntry.classId}');
  await Hive.box<ClassEntry>(HiveConstants.classBox).delete(classEntry.classId);
  await BackupReminder.recordDataChange();
}
