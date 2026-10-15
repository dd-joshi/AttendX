import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../core/hive_constants.dart';
import '../core/snapshot_storage.dart';
import 'models/class_entry.dart';
import 'models/snapshot_entry.dart';

/// Full-fidelity JSON backup of every class and attendance record.
///
/// The app stores all data in on-device Hive boxes, which Android deletes when
/// the app is uninstalled (for example when a signature change forces an
/// uninstall-and-reinstall). A backup file keeps the data safe across
/// reinstalls, device moves, and app-signing changes.
class BackupService {
  BackupService._();

  static const int currentVersion = 1;

  /// Serializes all local data into a human-readable JSON string.
  static String buildBackupJson() {
    final classBox = Hive.box<ClassEntry>(HiveConstants.classBox);
    final snapshotBox = Hive.box<SnapshotEntry>(HiveConstants.snapshotBox);

    final classes = classBox.values.map(_classToJson).toList(growable: false);
    final snapshots = snapshotBox.values
        .map(_snapshotToJson)
        .toList(growable: false);

    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'backupVersion': currentVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'classes': classes,
      'snapshots': snapshots,
    });
  }

  /// Merges a backup into the local boxes.
  ///
  /// Existing records with the same class id or snapshot id are replaced by
  /// the backup version; unrelated records are retained. Validate the entire
  /// file before writing so a malformed record cannot cause a partial import.
  /// Returns how many classes and attendance records were read.
  static Future<BackupRestoreResult> restoreFromJson(String raw) async {
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('The file is not valid JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The file is not an AttendX backup.');
    }
    final version = decoded['backupVersion'];
    if (version != currentVersion) {
      throw FormatException('Unsupported backup version: $version.');
    }
    if (decoded['classes'] is! List || decoded['snapshots'] is! List) {
      throw const FormatException(
        'The backup is missing classes or attendance.',
      );
    }
    final classes = <String, ClassEntry>{};
    for (final item in decoded['classes']) {
      final entry = _classFromJson(_object(item, 'class'));
      if (classes.containsKey(entry.classId)) {
        throw const FormatException(
          'The backup contains a duplicate class ID.',
        );
      }
      classes[entry.classId] = entry;
    }
    final snapshots = <String, SnapshotEntry>{};
    for (final item in decoded['snapshots']) {
      final entry = _snapshotFromJson(_object(item, 'attendance'));
      if (snapshots.containsKey(entry.snapshotId)) {
        throw const FormatException(
          'The backup contains duplicate attendance IDs.',
        );
      }
      snapshots[entry.snapshotId] = entry;
    }
    final classBox = Hive.box<ClassEntry>(HiveConstants.classBox);
    for (final entry in snapshots.values) {
      if (!classes.containsKey(entry.classId) &&
          !classBox.containsKey(entry.classId)) {
        throw const FormatException('Attendance refers to a missing class.');
      }
    }
    final snapshotBox = await openSnapshotBox();
    final existingSnapshotKeys = <String, dynamic>{};
    for (final key in snapshotBox.keys) {
      existingSnapshotKeys[snapshotBox.get(key)!.snapshotId] = key;
    }
    await classBox.putAll(classes);
    for (final entry in snapshots.values) {
      final key = existingSnapshotKeys[entry.snapshotId];
      if (key != null) {
        await snapshotBox.put(key, entry);
      } else {
        await snapshotBox.add(entry);
      }
    }
    return BackupRestoreResult(
      classes: classes.length,
      snapshots: snapshots.length,
    );
  }

  static Map<String, dynamic> _classToJson(ClassEntry entry) {
    final addedOn = <String, dynamic>{};
    for (final record
        in (entry.studentAddedOn ?? const <String, DateTime>{}).entries) {
      addedOn[record.key] = record.value.toIso8601String();
    }
    return <String, dynamic>{
      'classId': entry.classId,
      'title': entry.title,
      'classType': entry.effectiveClassType,
      'weekdays': entry.weekdays,
      'startHour': entry.startHour,
      'weekdayHours': entry.weekdayHours ?? <String, int>{},
      'weekdayMinutes': entry.weekdayMinutes ?? <String, int>{},
      'totalStudents': entry.totalStudents,
      'students': entry.students,
      'studentAddedOn': addedOn,
    };
  }

  static ClassEntry _classFromJson(Map<String, dynamic> json) {
    final students = <String, String>{};
    for (final entry in _object(json['students'], 'students').entries) {
      _roll(entry.key);
      students[entry.key] = _string(
        entry.value,
        'student name',
        allowEmpty: true,
      );
    }
    final addedOn = <String, DateTime>{};
    if (json['studentAddedOn'] != null) {
      for (final entry in _object(
        json['studentAddedOn'],
        'admission dates',
      ).entries) {
        _roll(entry.key);
        final date = _date(entry.value, 'admission date');
        addedOn[entry.key] = DateTime(date.year, date.month, date.day);
      }
    }
    if (json['weekdays'] is! List) {
      throw const FormatException('Invalid class weekdays.');
    }
    return ClassEntry(
      classId: _string(json['classId'], 'class ID'),
      title: _string(json['title'], 'class name'),
      classType: _sessionType(json['classType']),
      weekdays: [
        for (final day in json['weekdays']) _integer(day, 'weekday', max: 6),
      ],
      startHour: _integer(json['startHour'], 'start hour', max: 23),
      weekdayHours: _timeMap(json['weekdayHours'], 23),
      weekdayMinutes: _timeMap(json['weekdayMinutes'], 59),
      totalStudents: _integer(
        json['totalStudents'] ?? students.length,
        'student count',
      ),
      students: students,
      studentAddedOn: addedOn.isEmpty ? null : addedOn,
    );
  }

  static Map<String, dynamic> _snapshotToJson(SnapshotEntry entry) {
    return <String, dynamic>{
      'snapshotId': entry.snapshotId,
      'timestamp': entry.timestamp.toIso8601String(),
      'classId': entry.classId,
      'classTitle': entry.classTitle,
      'attendanceDate': entry.attendanceDate?.toIso8601String(),
      'sessionType': entry.sessionType,
      'topic': entry.topic,
      'snapshotData': entry.snapshotData,
    };
  }

  static SnapshotEntry _snapshotFromJson(Map<String, dynamic> json) {
    final rows = <Map<String, dynamic>>[];
    final rolls = <int>{};
    if (json['snapshotData'] is! List) {
      throw const FormatException('Invalid attendance rows.');
    }
    for (final rawRow in json['snapshotData']) {
      final row = _object(rawRow, 'attendance row');
      if (!rolls.add(_roll(row['roll']))) {
        throw const FormatException(
          'Attendance contains a repeated roll number.',
        );
      }
      _string(row['name'], 'student name', allowEmpty: true);
      if (row['isAbsent'] != null && row['isAbsent'] is! bool) {
        throw const FormatException('Invalid attendance mark.');
      }
      rows.add(row);
    }

    return SnapshotEntry(
      snapshotId: _string(json['snapshotId'], 'attendance ID'),
      timestamp: _date(json['timestamp'], 'creation date'),
      classId: _string(json['classId'], 'class ID'),
      classTitle: _string(json['classTitle'], 'class name'),
      snapshotData: rows,
      attendanceDate: json['attendanceDate'] == null
          ? null
          : _date(json['attendanceDate'], 'attendance date'),
      sessionType: _sessionType(json['sessionType']),
      topic: json['topic'] == null
          ? null
          : _string(json['topic'], 'topic', allowEmpty: true),
    );
  }

  static Map<String, dynamic> _object(dynamic value, String field) {
    if (value is Map<String, dynamic>) return value;
    throw FormatException('Invalid $field in backup.');
  }

  static String _string(
    dynamic value,
    String field, {
    bool allowEmpty = false,
  }) {
    if (value is String && (allowEmpty || value.trim().isNotEmpty)) {
      return value;
    }
    throw FormatException('Invalid $field in backup.');
  }

  static int _integer(dynamic value, String field, {int? max}) {
    if (value is int && value >= 0 && (max == null || value <= max)) {
      return value;
    }
    throw FormatException('Invalid $field in backup.');
  }

  static int _roll(dynamic value) {
    final roll = value is String ? int.tryParse(value) : null;
    if (roll == null || roll < 1 || value != roll.toString().padLeft(2, '0')) {
      throw const FormatException('Invalid roll number in backup.');
    }
    return roll;
  }

  static DateTime _date(dynamic value, String field) {
    final date = value is String ? DateTime.tryParse(value) : null;
    if (date != null) return date;
    throw FormatException('Invalid $field in backup.');
  }

  static String? _sessionType(dynamic value) {
    if (value == null ||
        value == SessionTypes.lecture ||
        value == SessionTypes.lab) {
      return value as String?;
    }
    throw const FormatException('Invalid lecture/lab type in backup.');
  }

  static Map<String, int>? _timeMap(dynamic value, int max) {
    if (value == null) return null;
    final result = <String, int>{};
    for (final entry in _object(value, 'schedule').entries) {
      if (!const ['0', '1', '2', '3', '4', '5', '6'].contains(entry.key)) {
        throw const FormatException('Invalid schedule weekday.');
      }
      result[entry.key] = _integer(entry.value, 'start time', max: max);
    }
    return result.isEmpty ? null : result;
  }
}

class BackupRestoreResult {
  const BackupRestoreResult({required this.classes, required this.snapshots});

  final int classes;
  final int snapshots;
}
