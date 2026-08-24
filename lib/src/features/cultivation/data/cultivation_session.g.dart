// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cultivation_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CultivationSessionAdapter extends TypeAdapter<CultivationSession> {
  @override
  final int typeId = 6;

  @override
  CultivationSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CultivationSession(
      id: fields[0] as String,
      startTime: fields[1] as DateTime,
      endTime: fields[2] as DateTime?,
      plannedDurationMinutes: fields[3] as int,
      actualDurationMinutes: fields[4] as int,
      subject: fields[5] as String,
      category: fields[6] as int,
      status: fields[7] as int,
      xpEarned: fields[8] as int,
      daoTraceKind: fields[9] as int?,
      daoTraceAmount: fields[10] as int,
      realmExpEarned: fields[11] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CultivationSession obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime)
      ..writeByte(3)
      ..write(obj.plannedDurationMinutes)
      ..writeByte(4)
      ..write(obj.actualDurationMinutes)
      ..writeByte(5)
      ..write(obj.subject)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.xpEarned)
      ..writeByte(9)
      ..write(obj.daoTraceKind)
      ..writeByte(10)
      ..write(obj.daoTraceAmount)
      ..writeByte(11)
      ..write(obj.realmExpEarned);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CultivationSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
