import 'package:hive/hive.dart';

part 'class_entry.g.dart';

/// What one class covers: [lecture] or [lab]. Each type keeps its own
/// schedule. Classes created before class types existed count as [lecture].
class ClassTypes {
  ClassTypes._();

  static const String lecture = 'lecture';
  static const String lab = 'lab';

  static String normalize(String? value) {
    return value == lab ? lab : lecture;
  }
}

@HiveType(typeId: 0)
class ClassEntry extends HiveObject {
  ClassEntry({
    required this.classId,
    required this.title,
    required this.weekdays,
    required this.startHour,
    required this.totalStudents,
    required this.students,
    this.studentAddedOn,
    this.weekdayHours,
    this.weekdayMinutes,
    this.classType,
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

  /// Optional per-weekday start hours, "0" = Mon … "6" = Sun, for classes
  /// that meet at different times on different days. Missing entries (and
  /// older classes) fall back to [startHour].
  @HiveField(7)
  Map<String, int>? weekdayHours;

  /// Optional per-weekday start minutes, paired with [weekdayHours]
  /// ("0" = Mon … "6" = Sun). Missing entries count as :00.
  @HiveField(9)
  Map<String, int>? weekdayMinutes;

  /// Start hour for one weekday, falling back to [startHour].
  int hourForWeekday(int weekday) {
    final hours = weekdayHours;
    if (hours != null) {
      final hour = hours['$weekday'];
      if (hour != null) return hour;
    }
    return startHour;
  }

  /// Start minute for one weekday, falling back to 0.
  int minuteForWeekday(int weekday) {
    return weekdayMinutes?['$weekday'] ?? 0;
  }

  @HiveField(4)
  int totalStudents;

  /// Roll number as String key — never Map<int, *>
  @HiveField(5)
  Map<String, String> students;

  /// The first date a later admission should appear in new attendance.
  ///
  /// Missing entries are intentional: rosters created before this field (and
  /// the first roster added to a class) are active for every attendance date.
  @HiveField(6)
  Map<String, DateTime>? studentAddedOn;

  /// [ClassTypes.lecture] or [ClassTypes.lab]. Older classes are null and
  /// count as [ClassTypes.lecture].
  @HiveField(8)
  String? classType;

  String get effectiveClassType => ClassTypes.normalize(classType);

  String get classTypeLabel =>
      effectiveClassType == ClassTypes.lab ? 'Lab' : 'Lecture';

  /// Keeps legacy classes usable if their old manual total exceeded the
  /// number of pasted names.
  int get rosterSize {
    var highestRoll = 0;
    for (final roll in students.keys) {
      final value = int.tryParse(roll);
      if (value != null && value > highestRoll) highestRoll = value;
    }
    return totalStudents > highestRoll ? totalStudents : highestRoll;
  }

  bool get hasRoster => rosterSize > 0;

  List<String> get orderedRolls => List<String>.generate(
    rosterSize,
    (index) => (index + 1).toString().padLeft(2, '0'),
  );
}
