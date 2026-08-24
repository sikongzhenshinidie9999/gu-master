// 道痕奖励配置（集中管理，供 RewardCalculator 使用）。
//
// 数值为阶段二初始值；长期成长曲线后续单独平衡，不在 Provider/UI/测试中散落。

import '../data/dao.dart';

/// 任务分类 → 道痕类型映射（配置驱动）。
///
/// - 炼体 → 力道
/// - 炼神 → 智道
/// - 炼蛊 → 炼道
/// - 悟道 → 特殊值 DaoKind.none，由 RewardCalculator 随机选择流派
/// - 杂务 / 炼气 / 其他 → 不产生流派道痕（不在映射中）
const Map<String, DaoKind> kCategoryDaoMap = {
  '炼体': DaoKind.li,
  '炼神': DaoKind.zhi,
  '炼蛊': DaoKind.lian,
  '悟道': DaoKind.none,
};

/// 基础道痕奖励。
const int kBasicDaoTraceReward = 5;

/// 炼体（力道）道痕奖励。
const int kCultivationBodyDaoTraceReward = 5;

/// 炼神（智道）道痕奖励。
const int kCultivationMindDaoTraceReward = 5;

/// 炼蛊（炼道）道痕奖励。
const int kRefiningDaoTraceReward = 5;

/// 悟道道痕倍率（高于普通分类）。
const double kWudaoDaoTraceMultiplier = 3.0;

/// 基础流派感悟奖励（每次对应流派任务；与道痕完全独立）。
const int kBasicRealmExpReward = 2;

/// 悟道感悟倍率（高于普通分类；与道痕倍率独立配置）。
const double kWudaoRealmExpMultiplier = 4.0;

/// 道痕类型 → 单次奖励（配置驱动，避免 if/else 链）。
const Map<DaoKind, int> kDaoKindRewardMap = {
  DaoKind.li: kCultivationBodyDaoTraceReward,
  DaoKind.zhi: kCultivationMindDaoTraceReward,
  DaoKind.lian: kRefiningDaoTraceReward,
};
