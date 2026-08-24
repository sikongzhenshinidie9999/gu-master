// 流派境界道痕阈值（集中管理；后续长期数值平衡只修改本文件）。
//
// 索引与 FactionLevel 前 5 级对应：
//   0 = 普通, 1 = 大师, 2 = 宗师, 3 = 大宗师, 4 = 无上大宗师
// 道主（FactionLevel.daoLord）不由道痕派生，是独立授予状态（见 DaoZhuState）。
const List<int> kFactionRealmThresholds = [
  0,       // 普通
  1000,    // 大师
  5000,    // 宗师
  20000,   // 大宗师
  100000,  // 无上大宗师
];
