// 修炼奖励计算（纯逻辑，不写 Hive、不修改 Provider）。
//
// 道痕（力量）与流派感悟（境界成长）是两个完全独立的奖励维度，互不换算。

import 'dart:math';

import 'package:sidequest/src/features/quests/data/quest_model.dart';

import '../data/dao.dart';
import 'reward_config.dart';

/// 任务完成后的修炼奖励（道痕 + 流派感悟）。
class QuestCultivationReward {
  /// 奖励所属流派（无流派奖励时为 null）。
  final DaoKind? daoKind;

  /// 道痕数量（力量；无道痕时为 0）。
  final int daoTraceAmount;

  /// 流派感悟数量（境界成长；与道痕完全独立；无感悟时为 0）。
  final int realmExpGain;

  const QuestCultivationReward({
    this.daoKind,
    this.daoTraceAmount = 0,
    this.realmExpGain = 0,
  });

  /// 是否产生流派道痕。
  bool get hasDaoTrace => daoKind != null && daoTraceAmount > 0;

  /// 是否产生流派感悟。
  bool get hasRealmExp => daoKind != null && realmExpGain > 0;
}

/// 根据任务分类计算修炼奖励（纯函数）。
///
/// - 道痕与流派感悟分别返回、分别写入两个独立数据源；
/// - [random] 可注入，用于测试悟道随机流派；不传时使用系统随机（运行时）；
/// - 悟道随机流派对道痕与感悟保持一致。
QuestCultivationReward computeCultivationReward(
  QuestModel quest, {
  Random? random,
}) {
  final daoKind = kCategoryDaoMap[quest.category];

  // 杂务 / 炼气 / 其他未映射分类 → 不产生流派道痕与流派感悟
  if (daoKind == null) {
    return const QuestCultivationReward();
  }

  // 悟道：随机选择一个流派，道痕与感悟收益均高于普通分类
  if (daoKind == DaoKind.none) {
    final rng = random ?? Random();
    const factions = Faction.values;
    final faction = factions[rng.nextInt(factions.length)];
    final amount = (kBasicDaoTraceReward * kWudaoDaoTraceMultiplier).round();
    final realmExp = (kBasicRealmExpReward * kWudaoRealmExpMultiplier).round();
    return QuestCultivationReward(
      daoKind: faction.daoKind,
      daoTraceAmount: amount,
      realmExpGain: realmExp,
    );
  }

  final amount = kDaoKindRewardMap[daoKind] ?? 0;
  return QuestCultivationReward(
    daoKind: daoKind,
    daoTraceAmount: amount,
    realmExpGain: kBasicRealmExpReward,
  );
}
