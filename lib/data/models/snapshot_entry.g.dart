// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'snapshot_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SnapshotEntryAdapter extends TypeAdapter<SnapshotEntry> {
  @override
  final int typeId = 1;

  @override
  SnapshotEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SnapshotEntry(
      snapshotId: fields[0] as String,
      timestamp: fields[1] as DateTime,
      classId: fields[2] as String,
      classTitle: fields[3] as String,
      snapshotData: (fields[4] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
    );
  }

  @override
  void write(BinaryWriter writer, SnapshotEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.snapshotId)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.classId)
      ..writeByte(3)
      ..write(obj.classTitle)
      ..writeByte(4)
      ..write(obj.snapshotData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SnapshotEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
