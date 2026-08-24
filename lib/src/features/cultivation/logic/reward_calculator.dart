// 道痕奖励计算（纯逻辑，不写 Hive、不修改 Provider）。

import 'dart:math';

import 'package:sidequest/src/features/quests/data/quest_model.dart';

import '../data/dao.dart';
import 'reward_config.dart';

/// 任务完成后的修炼奖励（道痕部分）。
class QuestCultivationReward {
  /// 获得道痕的流派（无流派道痕时为 null）。
  final DaoKind? daoKind;

  /// 道痕数量（无道痕时为 0）。
  final int daoTraceAmount;

  const QuestCultivationReward({this.daoKind, this.daoTraceAmount = 0});

  /// 是否产生流派道痕。
  bool get hasDaoTrace => daoKind != null && daoTraceAmount > 0;
}

/// 根据任务分类计算道痕奖励（纯函数）。
///
/// - [random] 可注入，用于测试悟道随机流派；不传时使用系统随机（运行时）。
QuestCultivationReward computeCultivationReward(
  QuestModel quest, {
  Random? random,
}) {
  final daoKind = kCategoryDaoMap[quest.category];

  // 杂务 / 炼气 / 其他未映射分类 → 不产生流派道痕
  if (daoKind == null) {
    return const QuestCultivationReward();
  }

  // 悟道：随机选择一个流派，道痕收益高于普通分类
  if (daoKind == DaoKind.none) {
    final rng = random ?? Random();
    const factions = Faction.values;
    final faction = factions[rng.nextInt(factions.length)];
    final amount = (kBasicDaoTraceReward * kWudaoDaoTraceMultiplier).round();
    return QuestCultivationReward(
      daoKind: faction.daoKind,
      daoTraceAmount: amount,
    );
  }

  final amount = kDaoKindRewardMap[daoKind] ?? 0;
  return QuestCultivationReward(daoKind: daoKind, daoTraceAmount: amount);
}
