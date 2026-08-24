// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gu_insect.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GuInsectAdapter extends TypeAdapter<GuInsect> {
  @override
  final int typeId = 3;

  @override
  GuInsect read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GuInsect(
      id: fields[0] as String,
      turn: fields[1] as int,
      refinedDaoLevel: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, GuInsect obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.turn)
      ..writeByte(2)
      ..write(obj.refinedDaoLevel);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GuInsectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
