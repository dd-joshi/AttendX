import 'package:hive_flutter/hive_flutter.dart';

import '../core/hive_constants.dart';
import '../core/snapshot_storage.dart';
import 'backup_reminder.dart';
import 'models/class_entry.dart';

class RosterValidationException implements Exception {
  const RosterValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

String normalizeStudentName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

List<String> parseRosterNames(String raw) {
  return raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map(normalizeStudentName)
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

List<int> activeRollsForDate(ClassEntry classEntry, DateTime date) {
  final attendanceDate = _dateOnly(date);
  final addedOn = classEntry.studentAddedOn ?? const <String, DateTime>{};

  final rolls = <int>[];
  final size = classEntry.rosterSize;
  for (var roll = 1; roll <= size; roll++) {
    final firstDate = addedOn[roll.toString().padLeft(2, '0')];
    if (firstDate == null || !_dateOnly(firstDate).isAfter(attendanceDate)) {
      rolls.add(roll);
    }
  }
  return rolls;
}

List<String> rosterNamesInOrder(ClassEntry classEntry) {
  return classEntry.orderedRolls
      .map((roll) => classEntry.students[roll] ?? '')
      .toList(growable: false);
}

String? validateAppendOnlyRoster({
  required List<String> existingNames,
  required List<String> proposedNames,
}) {
  if (proposedNames.isEmpty) {
    return 'No names found. Paste one student name per line.';
  }

  if (existingNames.any((name) => normalizeStudentName(name).isEmpty)) {
    return 'Name every existing roll in Manage class before updating the roster.';
  }

  if (proposedNames.length < existingNames.length) {
    return 'Existing students cannot be removed from the roster.';
  }

  for (var index = 0; index < existingNames.length; index++) {
    if (normalizeStudentName(existingNames[index]) !=
        normalizeStudentName(proposedNames[index])) {
      return 'Existing names and their order must stay unchanged. Use the pencil icon to correct a name.';
    }
  }

  if (proposedNames.length == existingNames.length) {
    return existingNames.isEmpty
        ? 'Add at least one student.'
        : 'No new students found. Append new names at the bottom.';
  }

  return null;
}

Future<ClassEntry> appendRoster({
  required String classId,
  required List<String> proposedNames,
  DateTime? now,
}) async {
  final box = Hive.box<ClassEntry>(HiveConstants.classBox);
  final classEntry = box.get(classId);
  if (classEntry == null) {
    throw const RosterValidationException('Class could not be found.');
  }

  final existingNames = rosterNamesInOrder(classEntry);
  final error = validateAppendOnlyRoster(
    existingNames: existingNames,
    proposedNames: proposedNames,
  );
  if (error != null) throw RosterValidationException(error);

  final students = Map<String, String>.from(classEntry.students);
  final addedOn = Map<String, DateTime>.from(
    classEntry.studentAddedOn ?? const <String, DateTime>{},
  );
  final isInitialRoster = existingNames.isEmpty;
  final addedDate = _dateOnly(now ?? DateTime.now());

  for (
    var index = existingNames.length;
    index < proposedNames.length;
    index++
  ) {
    final roll = (index + 1).toString().padLeft(2, '0');
    students[roll] = proposedNames[index];
    if (!isInitialRoster) addedOn[roll] = addedDate;
  }

  classEntry
    ..students = students
    ..totalStudents = students.length
    ..studentAddedOn = addedOn.isEmpty ? null : addedOn;
  await box.put(classEntry.classId, classEntry);
  await BackupReminder.recordDataChange();
  return classEntry;
}

Future<ClassEntry> saveStudentNameCorrection({
  required String classId,
  required int roll,
  required String name,
}) async {
  final snapshotBox = await openSnapshotBox();
  final trimmedName = normalizeStudentName(name);
  if (trimmedName.isEmpty) {
    throw const RosterValidationException('Student name cannot be empty.');
  }

  final classBox = Hive.box<ClassEntry>(HiveConstants.classBox);
  final classEntry = classBox.get(classId);
  if (classEntry == null) {
    throw const RosterValidationException('Class could not be found.');
  }

  final rollLabel = roll.toString().padLeft(2, '0');
  if (roll < 1 || roll > classEntry.rosterSize) {
    throw const RosterValidationException('Student roll could not be found.');
  }
  if (classEntry.students[rollLabel] == trimmedName) return classEntry;

  classEntry
    ..students = Map<String, String>.from(classEntry.students)
    ..students[rollLabel] = trimmedName
    ..totalStudents = classEntry.rosterSize;
  await classBox.put(classEntry.classId, classEntry);

  for (final snapshot in snapshotBox.values) {
    if (snapshot.classId != classEntry.classId) continue;

    var changed = false;
    final updatedData = snapshot.snapshotData.map((row) {
      if (row['roll'] == rollLabel && row['name'] != trimmedName) {
        changed = true;
        return {...row, 'name': trimmedName};
      }
      return row;
    }).toList();

    if (changed) {
      snapshot.snapshotData = updatedData;
      await snapshot.save();
    }
  }

  await BackupReminder.recordDataChange();
  return classEntry;
}

Future<ClassEntry> updateClassDetails({
  required String classId,
  required String title,
  required List<int> weekdays,
  required int startHour,
  Map<String, int> weekdayHours = const {},
  Map<String, int> weekdayMinutes = const {},
}) async {
  final snapshotBox = await openSnapshotBox();
  final normalizedTitle = title.trim();
  if (normalizedTitle.isEmpty) {
    throw const RosterValidationException('Class name cannot be empty.');
  }
  if (weekdays.isEmpty) {
    throw const RosterValidationException('Select at least one weekday.');
  }

  final classBox = Hive.box<ClassEntry>(HiveConstants.classBox);
  final classEntry = classBox.get(classId);
  if (classEntry == null) {
    throw const RosterValidationException('Class could not be found.');
  }

  final sortedWeekdays = List<int>.from(weekdays)..sort();
  classEntry
    ..title = normalizedTitle
    ..weekdays = sortedWeekdays
    ..startHour = startHour
    ..weekdayHours = weekdayHours.isEmpty
        ? null
        : Map<String, int>.from(weekdayHours)
    ..weekdayMinutes = weekdayMinutes.isEmpty
        ? null
        : Map<String, int>.from(weekdayMinutes);
  await classBox.put(classEntry.classId, classEntry);

  for (final snapshot in snapshotBox.values) {
    if (snapshot.classId == classEntry.classId &&
        snapshot.classTitle != normalizedTitle) {
      snapshot.classTitle = normalizedTitle;
      await snapshot.save();
    }
  }

  await BackupReminder.recordDataChange();
  return classEntry;
}
