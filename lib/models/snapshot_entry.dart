import 'package:hive/hive.dart';

part 'snapshot_entry.g.dart';

@HiveType(typeId: 1)
class SnapshotEntry extends HiveObject {
  @HiveField(0)
  late String snapshotId;

  @HiveField(1)
  late DateTime timestamp;

  @HiveField(2)
  late String classId;

  @HiveField(3)
  late String classTitle;

  @HiveField(4)
  late List<Map<String, dynamic>> snapshotData;
}