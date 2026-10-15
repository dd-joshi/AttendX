// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'class_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ClassEntryAdapter extends TypeAdapter<ClassEntry> {
  @override
  final int typeId = 0;

  @override
  ClassEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ClassEntry(
      classId: fields[0] as String,
      title: fields[1] as String,
      weekdays: (fields[2] as List).cast<int>(),
      startHour: fields[3] as int,
      totalStudents: fields[4] as int,
      students: (fields[5] as Map).cast<String, String>(),
      studentAddedOn: (fields[6] as Map?)?.cast<String, DateTime>(),
      weekdayHours: (fields[7] as Map?)?.cast<String, int>(),
      weekdayMinutes: (fields[9] as Map?)?.cast<String, int>(),
      classType: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ClassEntry obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.classId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.weekdays)
      ..writeByte(3)
      ..write(obj.startHour)
      ..writeByte(7)
      ..write(obj.weekdayHours)
      ..writeByte(9)
      ..write(obj.weekdayMinutes)
      ..writeByte(4)
      ..write(obj.totalStudents)
      ..writeByte(5)
      ..write(obj.students)
      ..writeByte(6)
      ..write(obj.studentAddedOn)
      ..writeByte(8)
      ..write(obj.classType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
