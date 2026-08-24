// 蛊虫定义（纯配置，非 Hive）。

import 'dao.dart';

/// 蛊虫定义。
class GuInsectDefinition {
  const GuInsectDefinition({
    required this.definitionId,
    required this.name,
    required this.turn,
    required this.faction,
    required this.minQuality,
    required this.maxQuality,
  });

  /// 稳定标识。
  final String definitionId;

  /// 蛊虫名称。
  final String name;

  /// 蛊虫转数（1~9）。
  final int turn;

  /// 所属流派。
  final Faction faction;

  /// 品质下限（0 普通 / 1 稀有 / 2 特殊）。
  final int minQuality;

  /// 品质上限。
  final int maxQuality;
}

/// 蛊虫定义表（测试用初始配置）。
const List<GuInsectDefinition> kGuInsectDefinitions = [
  GuInsectDefinition(
    definitionId: 'bronze_beetle',
    name: '青铜甲蛊',
    turn: 1,
    faction: Faction.li,
    minQuality: 0,
    maxQuality: 1,
  ),
  GuInsectDefinition(
    definitionId: 'iron_centipede',
    name: '铁线蜈蚣',
    turn: 3,
    faction: Faction.lian,
    minQuality: 0,
    maxQuality: 1,
  ),
  GuInsectDefinition(
    definitionId: 'blood_lotus_gu',
    name: '血莲蛊',
    turn: 5,
    faction: Faction.zhi,
    minQuality: 1,
    maxQuality: 2,
  ),
  GuInsectDefinition(
    definitionId: 'nine_turn_worm',
    name: '九转玄蚕',
    turn: 9,
    faction: Faction.li,
    minQuality: 1,
    maxQuality: 2,
  ),
];
