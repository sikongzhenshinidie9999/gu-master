// 炼蛊配置（集中管理，供 RefiningService 使用）。
//
// 数值为初始占位，后续长期平衡只改本文件。

/// 基础成功率。
const double kRefineBaseSuccessRate = 0.90;

/// 每转成功率惩罚。
const double kRefineTurnPenaltyPerTurn = 0.08;

/// 每级炼道境界成功率加成。
const double kRefineDaoLevelBonus = 0.04;

/// 最低成功率（下限保护，防止绝对不可能）。
const double kRefineMinSuccessRate = 0.05;

/// 最高成功率（上限保护，防止无脑必成）。
const double kRefineMaxSuccessRate = 0.95;

/// 每日蛊材掉落上限（阶段四初始值）。
const int kMaxDailyMaterialDrops = 10;

/// 阶段四过渡：玩家转数系统尚未实现，掉落暂用此默认转数；
/// 后续接入真实玩家转数后移除。
const int kDefaultMaterialDropTurn = 1;
