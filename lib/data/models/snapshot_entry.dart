import 'package:hive/hive.dart';

part 'snapshot_entry.g.dart';

@HiveType(typeId: 1)
class SnapshotEntry extends HiveObject {
  SnapshotEntry({
    required this.snapshotId,
    required this.timestamp,
    required this.classId,
    required this.classTitle,
    required this.snapshotData,
  });

  @HiveField(0)
  String snapshotId;

  @HiveField(1)
  DateTime timestamp;

  @HiveField(2)
  String classId;

  @HiveField(3)
  String classTitle;

  @HiveField(4)
  List<Map<String, dynamic>> snapshotData;
}
