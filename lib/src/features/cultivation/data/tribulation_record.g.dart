// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tribulation_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TribulationRecordAdapter extends TypeAdapter<TribulationRecord> {
  @override
  final int typeId = 2;

  @override
  TribulationRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TribulationRecord(
      realmLevel: fields[0] as int,
      stageIndex: fields[1] as int,
      failCount: fields[2] as int,
      lastAttemptAt: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TribulationRecord obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.realmLevel)
      ..writeByte(1)
      ..write(obj.stageIndex)
      ..writeByte(2)
      ..write(obj.failCount)
      ..writeByte(3)
      ..write(obj.lastAttemptAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TribulationRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
