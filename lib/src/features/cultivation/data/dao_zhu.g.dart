// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dao_zhu.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DaoZhuStateAdapter extends TypeAdapter<DaoZhuState> {
  @override
  final int typeId = 5;

  @override
  DaoZhuState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DaoZhuState(
      faction: fields[0] as int,
      crownedAt: fields[1] as DateTime,
      eraId: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DaoZhuState obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.faction)
      ..writeByte(1)
      ..write(obj.crownedAt)
      ..writeByte(2)
      ..write(obj.eraId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DaoZhuStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
