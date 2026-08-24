// 闭关奖励计算 —— 纯逻辑（不写 Hive、不依赖 Provider/UI、不修改输入）。

import 'dart:math';

import '../data/cultivation_session.dart';
import '../data/dao.dart';
import 'session_reward_config.dart';

/// 闭关奖励结果（纯数据）。
class SessionRewardResult {
  const SessionRewardResult({
    required this.xp,
    required this.daoKind,
    required this.daoTraceAmount,
    required this.realmExp,
  });

  /// 本次获得修为。
  final int xp;

  /// 实际道痕流派（null = 杂务无流派；悟道解析为随机具体流派）。
  final DaoKind? daoKind;

  /// 本次道痕数量（无流派时为 0）。
  final int daoTraceAmount;

  /// 本次流派感悟（无流派时为 0）。
  final int realmExp;
}

/// 计算闭关奖励（纯函数）。
///
/// - 学科 → 修炼分类（kSubjectCategoryMap），未命中归为杂务；
/// - 悟道随机解析为一个具体流派（[random] 可注入，便于测试）；
/// - 时长越长奖励越高；0 分钟/负数安全返回 0 奖励；
/// - 超过 [kSessionMaxMinutes] 时封顶，防止极端时长溢出；
/// - 不修改输入、无副作用。
SessionRewardResult computeSessionReward({
  required String subject,
  required int actualMinutes,
  Random? random,
}) {
  final safeMinutes = actualMinutes < 0 ? 0 : actualMinutes;
  final cappedMinutes = safeMinutes > kSessionMaxMinutes
      ? kSessionMaxMinutes
      : safeMinutes;
  if (cappedMinutes <= 0) {
    return const SessionRewardResult(
      xp: 0,
      daoKind: null,
      daoTraceAmount: 0,
      realmExp: 0,
    );
  }

  final category = kSubjectCategoryMap[subject] ??
      CultivationSessionCategory.misc;
  final mappedDao = sessionCategoryDaoKind(category);
  final isWudao = mappedDao == DaoKind.none;

  DaoKind? daoKind;
  if (isWudao) {
    final rng = random ?? Random();
    const factions = Faction.values;
    daoKind = factions[rng.nextInt(factions.length)].daoKind;
  } else {
    daoKind = mappedDao; // 炼神→智道；杂务→null
  }

  final multiplier = isWudao ? kSessionWudaoMultiplier : 1.0;
  final xp = (cappedMinutes * kSessionXpPerMinute).round();
  final daoTrace = daoKind == null
      ? 0
      : (cappedMinutes * kSessionDaoTracePerMinute * multiplier).round();
  final realmExp = daoKind == null
      ? 0
      : (cappedMinutes * kSessionRealmExpPerMinute * multiplier).round();

  return SessionRewardResult(
    xp: xp,
    daoKind: daoKind,
    daoTraceAmount: daoTrace,
    realmExp: realmExp,
  );
}
