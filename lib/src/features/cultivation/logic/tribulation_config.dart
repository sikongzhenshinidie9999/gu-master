// 渡劫配置（集中管理，供 TribulationService / CultivationNotifier 使用）。
//
// 「修为跨度」不在此复制阈值，而是从 realm.dart 的 kRealms 只读派生，
// 保持 realm.dart 为转数阈值的唯一事实来源。

import '../../stats/logic/realm.dart';

/// 各转数基础成功率（普通劫 6/7/8，尊者劫 9）。
const Map<int, double> kTribulationBaseSuccessRateByRealm = {
  6: 0.90,
  7: 0.80,
  8: 0.70,
  9: 0.50,
};

/// 每失败一次的成功率补偿。
const double kTribulationFailCompensationPerFail = 0.10;

/// 成功率下限。
const double kTribulationMinSuccessRate = 0.05;

/// 成功率上限。
const double kTribulationMaxSuccessRate = 0.95;

/// 冷却时长（成功与失败均进入冷却）。
const Duration kTribulationCooldown = Duration(hours: 24);

/// 失败惩罚分子（realmSpan × 1 / 3）。
const int kTribulationPenaltyNumerator = 1;

/// 失败惩罚分母。
const int kTribulationPenaltyDenominator = 3;

/// 普通渡劫每个转数的小阶数（stage 0..2，3 = 完成 sentinel）。
const int kTribulationStagesPerRealm = 3;

/// 「该转渡劫已完成」sentinel（终点，非第四次渡劫）。
const int kTribulationCompletedStageIndex = 3;

/// 合法转数：普通劫 6/7/8，尊者劫 9。
const Set<int> kTribulationRealmLevels = {6, 7, 8, 9};

/// 目标转数的修为跨度（realm.dart kRealms 只读派生，不复制阈值）。
///
/// span = kRealms[realmLevel].threshold - kRealms[realmLevel - 1].threshold；
/// realmLevel 越界返回 0（调用方按安全失败处理）。
int tribulationRealmSpan(int realmLevel) {
  if (realmLevel <= 0 || realmLevel >= kRealms.length) return 0;
  return kRealms[realmLevel].threshold - kRealms[realmLevel - 1].threshold;
}
