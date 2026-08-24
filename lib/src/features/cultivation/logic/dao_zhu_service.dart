// 道主资格 —— 纯逻辑（不授予、不写 Hive、不依赖 Provider/UI、无副作用）。
//
// 道主是「显式授予」的终局状态，绝不自动产生：
// - 唯一身份来源：profile.daoZhu != null；
// - 九转唯一来源：profile.nineTurnReached；
// - 各资格条件独立读取各自数据源，禁止互相推导；
// - 「当世理解最深」必须由调用方显式传入（多人竞争未来扩展），默认 false。

import '../data/dao.dart';
import '../data/faction_level.dart';
import '../data/player_profile.dart';
import 'faction_realm.dart';
import 'gu_power_config.dart';

/// 道主资格检查结果（纯数据）。
class DaoZhuEligibility {
  const DaoZhuEligibility({
    required this.nineTurnSatisfied,
    required this.factionRealmSatisfied,
    required this.daoTracesSatisfied,
    required this.deepestUnderstandingSatisfied,
    required this.alreadyGranted,
    required this.canGrant,
    this.failureReason,
  });

  /// ① 是否已真正突破九转（profile.nineTurnReached）。
  final bool nineTurnSatisfied;

  /// ② 指定流派是否达到无上大宗师（factionRealmExp → getFactionRealmProgress）。
  final bool factionRealmSatisfied;

  /// ③ 指定流派道痕是否达到九转要求（kDaoTracesRequiredByTurn[9]）。
  final bool daoTracesSatisfied;

  /// ④ 当世理解最深（显式传入，不自行推导）。
  final bool deepestUnderstandingSatisfied;

  /// ⑤ 是否已授予道主（profile.daoZhu != null，唯一身份来源）。
  final bool alreadyGranted;

  /// 是否可授予（全部条件满足且未授予）。
  final bool canGrant;

  /// 资格失败原因（可授予时为 null；按稳定顺序返回第一个未满足项）。
  final String? failureReason;
}

/// 检查指定流派是否具备道主资格（纯函数）。
///
/// 同时满足：
///   ① profile.nineTurnReached == true
///   ② 指定流派达到无上大宗师
///   ③ 指定流派道痕 ≥ kDaoTracesRequiredByTurn[9]
///   ④ isDeepestUnderstanding == true
///   ⑤ profile.daoZhu == null（已授予不可覆盖）
///
/// - 不修改 profile、无副作用；
/// - failureReason 顺序：已授予 → 未九转 → 境界不足 → 道痕不足 → 理解最深不足。
DaoZhuEligibility checkDaoZhuEligibility({
  required PlayerProfile profile,
  required Faction faction,
  bool isDeepestUnderstanding = false,
}) {
  // ⑤ 已授予（道主唯一身份来源）
  final alreadyGranted = profile.daoZhu != null;

  // ① 九转唯一来源
  final nineTurnSatisfied = profile.nineTurnReached;

  // ② 流派境界：复用 faction_realm 纯派生，不复制公式
  final realmExp = profile.factionRealmExp[faction.daoKind.index] ?? 0;
  final realmLevel = getFactionRealmProgress(faction, realmExp).level;
  final factionRealmSatisfied = realmLevel == FactionLevel.supremeGrandmaster;

  // ③ 流派道痕：九转阈值唯一来源（不写死 300000）
  final requirement = kDaoTracesRequiredByTurn[9];
  final traces = profile.daoTraces[faction.daoKind.index] ?? 0;
  final daoTracesSatisfied = requirement != null && traces >= requirement;

  // ④ 当世理解最深（显式传入）
  final deepestUnderstandingSatisfied = isDeepestUnderstanding;

  final canGrant = !alreadyGranted &&
      nineTurnSatisfied &&
      factionRealmSatisfied &&
      daoTracesSatisfied &&
      deepestUnderstandingSatisfied;

  String? failureReason;
  if (alreadyGranted) {
    failureReason = '已成为道主';
  } else if (!nineTurnSatisfied) {
    failureReason = '尚未突破九转';
  } else if (!factionRealmSatisfied) {
    failureReason = '该流派境界未达无上大宗师';
  } else if (!daoTracesSatisfied) {
    failureReason = '该流派道痕未达九转要求';
  } else if (!deepestUnderstandingSatisfied) {
    failureReason = '当世理解最深未满足';
  }

  return DaoZhuEligibility(
    nineTurnSatisfied: nineTurnSatisfied,
    factionRealmSatisfied: factionRealmSatisfied,
    daoTracesSatisfied: daoTracesSatisfied,
    deepestUnderstandingSatisfied: deepestUnderstandingSatisfied,
    alreadyGranted: alreadyGranted,
    canGrant: canGrant,
    failureReason: failureReason,
  );
}
