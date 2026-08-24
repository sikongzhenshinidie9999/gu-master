// 蛊材定义（纯配置，非 Hive）。
//
// 材料名称、品质、适用转数、掉落权重全部集中在本文件，不在 service/UI 散落。

/// 蛊材品质（可扩展）。
enum GuMaterialRarity {
  common('普通'),
  rare('稀有'),
  special('特殊');

  const GuMaterialRarity(this.label);

  /// 显示名。
  final String label;
}

/// 蛊材定义。
class GuMaterialDefinition {
  const GuMaterialDefinition({
    required this.materialId,
    required this.label,
    required this.rarity,
    required this.minTurn,
    required this.maxTurn,
    required this.dropWeight,
  });

  /// 稳定标识（如 'bronze_sand'）。
  final String materialId;

  /// 显示名。
  final String label;

  /// 品质。
  final GuMaterialRarity rarity;

  /// 适用转数下限（1~9）。
  final int minTurn;

  /// 适用转数上限（1~9）。
  final int maxTurn;

  /// 掉落权重（越大越常见）。
  final double dropWeight;
}

/// 蛊材定义表（初始配置，后续长期平衡只改本表）。
const List<GuMaterialDefinition> kGuMaterialDefinitions = [
  GuMaterialDefinition(
    materialId: 'bronze_sand',
    label: '青铜沙',
    rarity: GuMaterialRarity.common,
    minTurn: 1,
    maxTurn: 9,
    dropWeight: 100,
  ),
  GuMaterialDefinition(
    materialId: 'iron_powder',
    label: '玄铁粉',
    rarity: GuMaterialRarity.common,
    minTurn: 1,
    maxTurn: 9,
    dropWeight: 60,
  ),
  GuMaterialDefinition(
    materialId: 'blood_lotus',
    label: '血莲瓣',
    rarity: GuMaterialRarity.rare,
    minTurn: 3,
    maxTurn: 9,
    dropWeight: 20,
  ),
  GuMaterialDefinition(
    materialId: 'nine_turn_spirit',
    label: '九转精魄',
    rarity: GuMaterialRarity.special,
    minTurn: 7,
    maxTurn: 9,
    dropWeight: 2,
  ),
];
