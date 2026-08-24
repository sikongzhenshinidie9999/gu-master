// 蛊虫威能（纯逻辑，不依赖 Hive / Provider，无副作用）。
//
// 公式：
//   蛊虫威能 = basePower(turn) × qualityMultiplier(quality) × daoFactor
//   daoFactor = 1 + kDaoMaxMultiplier × unlockRatio × (traces / (traces + halfSaturation))
//   unlockRatio = min(1, traces / requiredTraces(turn))；requiredTraces == 0 视为完全解锁。
//
// 语义约束（阶段三修正锁死）：
// - 只读取 daoTraces（力量），绝不读取 factionRealmExp（感悟）；
// - daoTraces 不参与 FactionLevel 派生（见 faction_realm.dart）。

import '../data/dao.dart';
import '../data/gu_insect.dart';
import '../data/gu_insect_definition.dart';
import 'gu_power_config.dart';

/// 蛊虫威能分解（纯数据，用于 UI 展示，不落 Hive）。
class GuInsectPowerResult {
  const GuInsectPowerResult({
    required this.basePower,
    required this.qualityMultiplier,
    required this.daoMultiplier,
    required this.unlockRatio,
    required this.totalPower,
  });

  /// 转数基础威能。
  final double basePower;

  /// 品质倍率。
  final double qualityMultiplier;

  /// 道痕加成倍率（daoFactor，最低 1.0，上限 1 + kDaoMaxMultiplier）。
  final double daoMultiplier;

  /// 道痕解锁比例（0.0~1.0）。
  final double unlockRatio;

  /// 最终威能 = basePower × qualityMultiplier × daoMultiplier。
  final double totalPower;
}

/// 单只蛊虫威能（纯函数）。
///
/// - [insect]：蛊虫（definitionId 找不到时使用其 turn/faction/quality 快照兜底）；
/// - [daoTraces]：DaoKind.index -> 道痕数量，只读取蛊虫所属流派对应的道痕；
/// - [definitions]：可注入蛊虫定义表（默认全局配置）；
/// - faction 非法 / quality 越界 / traces 极端值时安全返回，不抛异常、无 NaN/Infinity。
GuInsectPowerResult getGuInsectPower({
  required GuInsect insect,
  required Map<int, int> daoTraces,
  List<GuInsectDefinition> definitions = kGuInsectDefinitions,
}) {
  final definition = _findDefinition(insect.definitionId, definitions);

  final turn = definition?.turn ?? insect.turn;
  final factionIndex = definition?.faction.index ?? insect.faction;
  final quality = _clampQuality(insect.quality);

  final basePower = kInsectBasePowerByTurn[turn] ?? 0.0;
  final qualityMultiplier = kQualityPowerMultipliers[quality];

  final faction = _resolveFaction(factionIndex);
  if (faction == null) {
    // 非法流派：无法确定对应道痕，道痕加成取中性值 1.0，安全返回。
    return GuInsectPowerResult(
      basePower: basePower,
      qualityMultiplier: qualityMultiplier,
      daoMultiplier: 1.0,
      unlockRatio: 0.0,
      totalPower: basePower * qualityMultiplier,
    );
  }

  final rawTraces = daoTraces[faction.daoKind.index] ?? 0;
  final traces = rawTraces < 0 ? 0 : rawTraces;
  final unlockRatio = _unlockRatio(turn, traces);
  final daoMultiplier = _daoFactor(turn, traces);

  return GuInsectPowerResult(
    basePower: basePower,
    qualityMultiplier: qualityMultiplier,
    daoMultiplier: daoMultiplier,
    unlockRatio: unlockRatio,
    totalPower: basePower * qualityMultiplier * daoMultiplier,
  );
}

/// 指定流派总威能（纯函数）：只统计该流派蛊虫，逐只按对应道痕计算后求和。
///
/// 绝不读取 factionRealmExp。
double calculateFactionPower({
  required Faction faction,
  required Map<int, int> daoTraces,
  required List<GuInsect> insects,
  List<GuInsectDefinition> definitions = kGuInsectDefinitions,
}) {
  var total = 0.0;
  for (final insect in insects) {
    if (insect.faction != faction.index) continue;
    total += getGuInsectPower(
      insect: insect,
      daoTraces: daoTraces,
      definitions: definitions,
    ).totalPower;
  }
  return total;
}

GuInsectDefinition? _findDefinition(
    String definitionId, List<GuInsectDefinition> definitions) {
  for (final d in definitions) {
    if (d.definitionId == definitionId) return d;
  }
  return null;
}

Faction? _resolveFaction(int index) {
  if (index < 0 || index >= Faction.values.length) return null;
  return Faction.values[index];
}

int _clampQuality(int quality) {
  if (quality < 0) return 0;
  if (quality >= kQualityPowerMultipliers.length) {
    return kQualityPowerMultipliers.length - 1;
  }
  return quality;
}

/// unlockRatio = min(1, traces / required)；required == 0 视为完全解锁。
double _unlockRatio(int turn, int traces) {
  final required = kDaoTracesRequiredByTurn[turn] ?? 0;
  if (required <= 0) return 1.0;
  return (traces / required).clamp(0.0, 1.0);
}

/// daoFactor = 1 + kDaoMaxMultiplier × unlockRatio × (traces / (traces + half))。
double _daoFactor(int turn, int traces) {
  final half = kDaoHalfSaturationByTurn[turn] ?? 0.0;
  final saturation = half <= 0 ? 0.0 : traces / (traces + half);
  final unlockRatio = _unlockRatio(turn, traces);
  return 1.0 + kDaoMaxMultiplier * unlockRatio * saturation;
}
