// 九转突破前置条件 —— 纯逻辑（不执行突破、不写 Hive、不依赖 Provider/UI）。
//
// 四条件彼此独立，分别读取各自数据源，禁止互相推导：
//   ① 主修流派道痕 ≥ 九转所需道痕     ← daoTraces
//   ② 主修流派境界 = 无上大宗师       ← factionRealmExp → getFactionRealmProgress
//   ③ 仙元 = 白荔仙元                 ← profile.xianYuan
//   ④ 已完成九转尊者级渡劫            ← 外部传入（6C 实现真正计算）
//
// 语义边界（阶段三/五锁死）：
//   - 道痕只能读取 daoTraces，境界只能读取 factionRealmExp，二者禁止转换；
//   - realm.dart 的 totalXp 不参与真正九转判断；
//   - 九转道痕阈值唯一来源：kDaoTracesRequiredByTurn[9]（gu_power_config.dart）。

import '../data/dao.dart';
import '../data/faction_level.dart';
import '../data/player_profile.dart';
import 'faction_realm.dart';
import 'gu_power_config.dart';

/// 九转前置条件检查结果（纯数据）。
class NineTurnPrerequisiteResult {
  const NineTurnPrerequisiteResult({
    required this.canBreakthrough,
    required this.primaryFaction,
    required this.daoTraceRequirement,
    required this.currentDaoTraces,
    required this.daoTracesSatisfied,
    required this.factionRealmLevel,
    required this.factionRealmSatisfied,
    required this.xianYuanSatisfied,
    required this.tribulationSatisfied,
  });

  /// 四条件是否全部满足。
  final bool canBreakthrough;

  /// 主修流派（无有效主修流派时为 null）。
  final Faction? primaryFaction;

  /// 九转所需道痕（配置缺失时为 null）。
  final int? daoTraceRequirement;

  /// 主修流派当前道痕。
  final int currentDaoTraces;

  /// ① 道痕是否满足。
  final bool daoTracesSatisfied;

  /// 主修流派当前境界（无主修流派时为 null）。
  final FactionLevel? factionRealmLevel;

  /// ② 境界是否满足（无上大宗师）。
  final bool factionRealmSatisfied;

  /// ③ 仙元是否为白荔仙元。
  final bool xianYuanSatisfied;

  /// ④ 尊者级渡劫是否完成（外部传入）。
  final bool tribulationSatisfied;
}

/// 派生主修流派（纯函数，不修改 profile、不写 Hive）。
///
/// - 6B：若 PlayerProfile 显式设置了合法的 primaryFaction（Faction.index），优先使用；
/// - 未设置或非法时，按 factionRealmExp 最高者派生；
/// - 多个流派感悟相同 → 取 Faction.values 中靠前者（稳定、确定性 tie-breaker）；
/// - 没有任何流派感悟（全部缺失/≤0）→ 返回 null（安全缺失，不崩溃）；
/// - 绝不依据 daoTraces 判断主修流派。
Faction? resolvePrimaryFaction(PlayerProfile profile) {
  final explicit = profile.primaryFaction;
  if (explicit != null) {
    final faction = _resolveFaction(explicit);
    if (faction != null) return faction;
  }

  Faction? best;
  var bestExp = -1;
  for (final faction in Faction.values) {
    final exp = profile.factionRealmExp[faction.daoKind.index] ?? 0;
    if (exp > bestExp) {
      bestExp = exp;
      best = faction;
    }
    // 相等时不更新 → 保持 Faction.values 顺序靠前者，结果稳定
  }
  if (bestExp <= 0) return null;
  return best;
}

Faction? _resolveFaction(int index) {
  if (index < 0 || index >= Faction.values.length) return null;
  return Faction.values[index];
}

/// 检查九转突破前置条件（纯函数）。
///
/// - [tribulationSatisfied]：尊者级渡劫是否完成，由外部传入（6C 实现真正计算）；
/// - 四个布尔条件分别计算、分别暴露，最后取与得到 canBreakthrough；
/// - 非法/缺失数据安全返回（不抛异常，条件视为不满足）。
NineTurnPrerequisiteResult checkNineTurnPrerequisites({
  required PlayerProfile profile,
  required bool tribulationSatisfied,
}) {
  final primary = resolvePrimaryFaction(profile);

  final requirement = kDaoTracesRequiredByTurn[9];
  final currentTraces =
      primary == null ? 0 : (profile.daoTraces[primary.daoKind.index] ?? 0);
  final daoTracesSatisfied =
      primary != null && requirement != null && currentTraces >= requirement;

  final realmLevel = primary == null
      ? null
      : getFactionRealmProgress(
              primary, profile.factionRealmExp[primary.daoKind.index] ?? 0)
          .level;
  final factionRealmSatisfied = realmLevel == FactionLevel.supremeGrandmaster;

  final xianYuanSatisfied = profile.xianYuan == XianYuanType.baili.index;

  final canBreakthrough = daoTracesSatisfied &&
      factionRealmSatisfied &&
      xianYuanSatisfied &&
      tribulationSatisfied;

  return NineTurnPrerequisiteResult(
    canBreakthrough: canBreakthrough,
    primaryFaction: primary,
    daoTraceRequirement: requirement,
    currentDaoTraces: currentTraces,
    daoTracesSatisfied: daoTracesSatisfied,
    factionRealmLevel: realmLevel,
    factionRealmSatisfied: factionRealmSatisfied,
    xianYuanSatisfied: xianYuanSatisfied,
    tribulationSatisfied: tribulationSatisfied,
  );
}
