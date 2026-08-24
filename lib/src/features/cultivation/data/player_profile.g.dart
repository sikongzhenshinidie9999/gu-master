// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlayerProfileAdapter extends TypeAdapter<PlayerProfile> {
  @override
  final int typeId = 1;

  @override
  PlayerProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlayerProfile(
      totalXp: fields[0] as int,
      currentCultivation: fields[1] as int,
      daoTraces: (fields[2] as Map?)?.cast<int, int>(),
      factionLevels: (fields[3] as Map?)?.cast<int, int>(),
      tribulations: (fields[4] as List?)?.cast<TribulationRecord>(),
      guMaterials: (fields[5] as List?)?.cast<GuMaterial>(),
      guInsects: (fields[6] as List?)?.cast<GuInsect>(),
      xianYuan: fields[7] as int,
      factionRealmExp: (fields[9] as Map?)?.cast<int, int>(),
      daoZhu: fields[8] as DaoZhuState?,
      primaryFaction: fields[10] as int?,
      nineTurnReached: fields[11] == null ? false : fields[11] as bool,
      nineTurnBreakthroughAt: fields[12] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PlayerProfile obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.totalXp)
      ..writeByte(1)
      ..write(obj.currentCultivation)
      ..writeByte(2)
      ..write(obj.daoTraces)
      ..writeByte(3)
      ..write(obj.factionLevels)
      ..writeByte(4)
      ..write(obj.tribulations)
      ..writeByte(5)
      ..write(obj.guMaterials)
      ..writeByte(6)
      ..write(obj.guInsects)
      ..writeByte(7)
      ..write(obj.xianYuan)
      ..writeByte(8)
      ..write(obj.daoZhu)
      ..writeByte(9)
      ..write(obj.factionRealmExp)
      ..writeByte(10)
      ..write(obj.primaryFaction)
      ..writeByte(11)
      ..write(obj.nineTurnReached)
      ..writeByte(12)
      ..write(obj.nineTurnBreakthroughAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
