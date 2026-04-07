import 'package:hive/hive.dart';

part 'class_entry.g.dart';

@HiveType(typeId: 0)
class ClassEntry extends HiveObject {
  ClassEntry({
    required this.classId,
    required this.title,
    required this.weekdays,
    required this.startHour,
    required this.totalStudents,
    required this.students,
  });

  @HiveField(0)
  String classId;

  @HiveField(1)
  String title;

  /// 0 = Mon … 6 = Sun
  @HiveField(2)
  List<int> weekdays;

  /// 24h hour
  @HiveField(3)
  int startHour;

  @HiveField(4)
  int totalStudents;

  /// Roll number as String key — never Map<int, *>
  @HiveField(5)
  Map<String, String> students;
}
