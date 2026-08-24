// 蛊虫威能配置（集中管理，供 GuPowerService 使用）。
//
// 数值为阶段五初始占位；后续长期平衡只改本文件，不在 service/Provider/UI 中散落。
//
// 语义约定（与阶段三修正保持一致）：
// - daoTraces = 流派力量积累，参与蛊虫威能；
// - factionRealmExp = 流派感悟，唯一决定 FactionLevel，绝不参与威能；
// - 道痕与境界双向禁止转换。

/// 每转基础威能（1~9 转）。
///
/// 必须随转数明显超线性增长，保证：
/// 「1 转蛊虫吃满道痕 + 特殊品质」仍远低于「9 转蛊虫 0 道痕 + 普通品质」。
const Map<int, double> kInsectBasePowerByTurn = {
  1: 100,
  2: 250,
  3: 600,
  4: 1500,
  5: 4000,
  6: 10000,
  7: 25000,
  8: 60000,
  9: 150000,
};

/// 品质倍率（索引 = 品质：0 普通 / 1 稀有 / 2 特殊）。
const List<double> kQualityPowerMultipliers = [1.0, 1.5, 2.5];

/// 道痕最大加成倍数：daoFactor 上限 = 1 + kDaoMaxMultiplier。
const double kDaoMaxMultiplier = 2.0;

/// 每转道痕半饱和值：traces 达到该值时饱和度 = 0.5（软上限曲线 x/(x+K)）。
const Map<int, double> kDaoHalfSaturationByTurn = {
  1: 500,
  2: 1000,
  3: 2000,
  4: 5000,
  5: 10000,
  6: 20000,
  7: 50000,
  8: 100000,
  9: 200000,
};

/// 每转道痕解锁阈值：unlockRatio = min(1, traces / required)。
///
/// - required == 0 表示完全解锁；
/// - 九转 = 300000，与阶段六九转前置条件共用同一数值入口（本阶段不实现九转突破）。
const Map<int, int> kDaoTracesRequiredByTurn = {
  1: 0,
  2: 0,
  3: 1000,
  4: 5000,
  5: 10000,
  6: 30000,
  7: 60000,
  8: 120000,
  9: 300000,
};
