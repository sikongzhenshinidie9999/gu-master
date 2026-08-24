// 蛊材掉落（纯逻辑，不修改 Hive、不依赖 Provider/UI）。

import 'dart:math';

import '../data/gu_material_definition.dart';

/// 根据当前转数筛选可掉落蛊材，并按 dropWeight 加权随机。
///
/// - [currentTurn]：玩家当前转数（1~9）；
/// - [random] 可注入，便于测试；
/// - [definitions] 可注入自定义定义表；
/// - 没有合法材料时返回 null。
String? rollMaterialDrop({
  required int currentTurn,
  Random? random,
  List<GuMaterialDefinition> definitions = kGuMaterialDefinitions,
}) {
  final eligible = definitions
      .where((d) => currentTurn >= d.minTurn && currentTurn <= d.maxTurn)
      .toList();
  if (eligible.isEmpty) return null;

  final rng = random ?? Random();
  final totalWeight = eligible.fold<double>(0, (sum, d) => sum + d.dropWeight);
  var roll = rng.nextDouble() * totalWeight;
  for (final d in eligible) {
    roll -= d.dropWeight;
    if (roll < 0) return d.materialId;
  }
  return eligible.last.materialId;
}
