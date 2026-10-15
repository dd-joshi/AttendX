import 'package:hive/hive.dart';

part 'snapshot_entry.g.dart';

/// Session kinds recorded per attendance date.
///
/// One attendance record exists per class, date, and session type, so a class
/// can hold both a lecture and a lab on the same day.
class SessionTypes {
  SessionTypes._();

  static const String lecture = 'lecture';
  static const String lab = 'lab';

  static const List<String> values = [lecture, lab];

  /// Older records predate session types and count as [lecture].
  static String normalize(String? value) {
    return value == lab ? lab : lecture;
  }
}

@HiveType(typeId: 1)
class SnapshotEntry extends HiveObject {
  SnapshotEntry({
    required this.snapshotId,
    required this.timestamp,
    required this.classId,
    required this.classTitle,
    required this.snapshotData,
    this.attendanceDate,
    this.sessionType,
    this.topic,
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

  /// The faculty-selected attendance date. Older records fall back to
  /// [timestamp], which was previously used for both creation and attendance.
  @HiveField(5)
  DateTime? attendanceDate;

  /// [SessionTypes.lecture] or [SessionTypes.lab]. Older records are null and
  /// read back as [SessionTypes.lecture].
  @HiveField(6)
  String? sessionType;

  /// Short topic covered in this session, e.g. "Unit 2 — Transformers".
  /// One per class, date, and session type.
  @HiveField(9)
  String? topic;

  DateTime get effectiveAttendanceDate {
    final value = attendanceDate ?? timestamp;
    return DateTime(value.year, value.month, value.day);
  }

  String get effectiveSessionType => SessionTypes.normalize(sessionType);

  bool get isLab => effectiveSessionType == SessionTypes.lab;
}
