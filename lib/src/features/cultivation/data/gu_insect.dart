import 'package:hive/hive.dart';

part 'gu_insect.g.dart';

/// 蛊虫。
///
/// 蛊虫只能通过炼蛊获得。
/// 名称、成功率、配方等配置数据不重复写入 Hive（见 GuInsectDefinition / GuRecipe）。
@HiveType(typeId: 3)
class GuInsect {
  /// 唯一标识。
  @HiveField(0)
  final String id;

  /// 蛊虫转数。
  @HiveField(1)
  final int turn;

  /// 炼制成功时玩家的炼道境界（FactionLevel.index 快照）。
  @HiveField(2)
  final int refinedDaoLevel;

  /// 对应蛊虫定义（GuInsectDefinition.definitionId）。
  @HiveField(3)
  final String definitionId;

  /// 所属流派（Faction.index）。
  @HiveField(4)
  final int faction;

  /// 炼制时最终生成的品质（0 普通 / 1 稀有 / 2 特殊）。
  @HiveField(5)
  final int quality;

  GuInsect({
    required this.id,
    required this.turn,
    required this.refinedDaoLevel,
    required this.definitionId,
    required this.faction,
    required this.quality,
  });
}
