import 'package:hive/hive.dart';

part 'class_entry.g.dart';

@HiveType(typeId: 0)
class ClassEntry extends HiveObject {
  @HiveField(0)
  late String classId;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late List<int> weekdays;

  @HiveField(3)
  late int startHour;

  @HiveField(4)
  late int totalStudents;

  @HiveField(5)
  late Map<String, String> students;
}