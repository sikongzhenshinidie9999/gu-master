// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gu_material.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GuMaterialAdapter extends TypeAdapter<GuMaterial> {
  @override
  final int typeId = 4;

  @override
  GuMaterial read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GuMaterial(
      type: fields[0] as int,
      quantity: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, GuMaterial obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.quantity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GuMaterialAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
