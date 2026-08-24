// 蛊方（纯配置，非 Hive）。
//
// 方案 C：固定核心蛊方（配方 → 固定蛊虫种类），品质/稀有由炼蛊时随机。

/// 蛊方中单种材料的用量。
class GuRecipeMaterial {
  const GuRecipeMaterial({required this.materialId, required this.quantity});

  /// 蛊材标识。
  final String materialId;

  /// 所需数量。
  final int quantity;
}

/// 蛊方：固定蛊虫定义 + 材料清单。
class GuRecipe {
  const GuRecipe({required this.insectDefinitionId, required this.materials});

  /// 目标蛊虫定义标识。
  final String insectDefinitionId;

  /// 材料清单。
  final List<GuRecipeMaterial> materials;
}

/// 蛊方表（测试用初始配置）。
const List<GuRecipe> kGuRecipes = [
  GuRecipe(
    insectDefinitionId: 'bronze_beetle',
    materials: [
      GuRecipeMaterial(materialId: 'bronze_sand', quantity: 3),
      GuRecipeMaterial(materialId: 'iron_powder', quantity: 1),
    ],
  ),
  GuRecipe(
    insectDefinitionId: 'iron_centipede',
    materials: [
      GuRecipeMaterial(materialId: 'iron_powder', quantity: 5),
      GuRecipeMaterial(materialId: 'blood_lotus', quantity: 2),
    ],
  ),
  GuRecipe(
    insectDefinitionId: 'blood_lotus_gu',
    materials: [
      GuRecipeMaterial(materialId: 'blood_lotus', quantity: 4),
      GuRecipeMaterial(materialId: 'iron_powder', quantity: 8),
    ],
  ),
  GuRecipe(
    insectDefinitionId: 'nine_turn_worm',
    materials: [
      GuRecipeMaterial(materialId: 'blood_lotus', quantity: 10),
      GuRecipeMaterial(materialId: 'nine_turn_spirit', quantity: 3),
    ],
  ),
];
