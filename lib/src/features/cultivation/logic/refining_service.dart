// 炼蛊（纯逻辑，不修改 Hive / PlayerProfile；结果由调用方决定持久化）。

import 'dart:math';

import '../data/faction_level.dart';
import '../data/gu_insect_definition.dart';
import '../data/gu_recipe.dart';
import 'refining_config.dart';

/// 炼蛊成功率（纯函数）。
///
/// 蛊虫转数越高成功率越低；炼道境界越高成功率越高；最终 clamp 到 min/max。
double refiningSuccessRate({
  required int insectTurn,
  required FactionLevel lianDaoLevel,
}) {
  final rate = kRefineBaseSuccessRate -
      kRefineTurnPenaltyPerTurn * (insectTurn - 1) +
      kRefineDaoLevelBonus * lianDaoLevel.index;
  return rate.clamp(kRefineMinSuccessRate, kRefineMaxSuccessRate).toDouble();
}

/// 成功炼出的蛊虫（纯逻辑结果对象；后续阶段再落 Hive）。
class GainedGuInsect {
  const GainedGuInsect({
    required this.definitionId,
    required this.name,
    required this.turn,
    required this.faction,
    required this.quality,
    required this.refinedDaoLevel,
  });

  final String definitionId;
  final String name;
  final int turn;
  final int faction;
  final int quality;
  final int refinedDaoLevel;
}

/// 炼蛊结果（纯数据）。
class RefiningResult {
  const RefiningResult({
    required this.success,
    this.consumedMaterials = const [],
    this.gainedInsect,
    this.failureReason,
  });

  final bool success;

  /// 本次消耗的蛊材（materialId -> 数量）；成功与失败均按蛊方扣除（可配置返还）。
  final List<GuRecipeMaterial> consumedMaterials;

  /// 成功时生成的蛊虫。
  final GainedGuInsect? gainedInsect;

  final String? failureReason;
}

/// 执行炼蛊（纯函数）。
///
/// - 检查蛊方与蛊虫定义是否存在；
/// - 检查材料是否足够（[inventory] 只读，不修改）；
/// - 计算成功率；[random] 可注入；
/// - 成功：随机生成合法品质的蛊虫并记录炼道境界快照；
/// - 失败：返回失败结果（蛊方材料按配置消耗）。
RefiningResult refineGuInsect({
  required String insectDefinitionId,
  required FactionLevel lianDaoLevel,
  required Map<String, int> inventory,
  Random? random,
  List<GuRecipe> recipes = kGuRecipes,
  List<GuInsectDefinition> definitions = kGuInsectDefinitions,
}) {
  final recipe = _findRecipe(insectDefinitionId, recipes);
  if (recipe == null) {
    return const RefiningResult(success: false, failureReason: '未找到蛊方');
  }

  final definition = _findDefinition(insectDefinitionId, definitions);
  if (definition == null) {
    return const RefiningResult(success: false, failureReason: '未找到蛊虫定义');
  }

  for (final m in recipe.materials) {
    if ((inventory[m.materialId] ?? 0) < m.quantity) {
      return const RefiningResult(success: false, failureReason: '蛊材不足');
    }
  }

  final rate = refiningSuccessRate(
    insectTurn: definition.turn,
    lianDaoLevel: lianDaoLevel,
  );
  final rng = random ?? Random();
  final success = rng.nextDouble() < rate;

  if (!success) {
    return RefiningResult(
      success: false,
      consumedMaterials: recipe.materials,
      failureReason: '炼制失败',
    );
  }

  final quality = definition.minQuality +
      rng.nextInt(definition.maxQuality - definition.minQuality + 1);
  final insect = GainedGuInsect(
    definitionId: definition.definitionId,
    name: definition.name,
    turn: definition.turn,
    faction: definition.faction.index,
    quality: quality,
    refinedDaoLevel: lianDaoLevel.index,
  );
  return RefiningResult(
    success: true,
    consumedMaterials: recipe.materials,
    gainedInsect: insect,
  );
}

GuRecipe? _findRecipe(String id, List<GuRecipe> recipes) {
  for (final r in recipes) {
    if (r.insectDefinitionId == id) return r;
  }
  return null;
}

GuInsectDefinition? _findDefinition(
    String id, List<GuInsectDefinition> definitions) {
  for (final d in definitions) {
    if (d.definitionId == id) return d;
  }
  return null;
}
