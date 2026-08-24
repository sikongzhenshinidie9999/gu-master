// 闭关（番茄钟）奖励配置 —— 纯配置，不参与计算逻辑。
//
// 学科 → 修炼分类映射集中在本文件；奖励公式在 session_reward_calculator.dart。

import '../data/dao.dart';
import '../data/cultivation_session.dart';

/// 番茄钟预设时长（分钟）。
const List<int> kSessionPresetMinutes = [25, 45, 90];

/// 学科 → 修炼分类映射。
///
/// 未命中的学科归为杂务。
const Map<String, CultivationSessionCategory> kSubjectCategoryMap = {
  '数学': CultivationSessionCategory.wudao,
  '英语': CultivationSessionCategory.shen,
  '408': CultivationSessionCategory.wudao,
  '专业课': CultivationSessionCategory.wudao,
};

/// 修炼分类 → 道痕类型（DaoKind）。
///
/// - 悟道 → DaoKind.none（标记，由计算器解析为随机流派，倍率更高）；
/// - 杂务 → null（无流派奖励，仅修为）。
DaoKind? sessionCategoryDaoKind(CultivationSessionCategory category) {
  switch (category) {
    case CultivationSessionCategory.ti:
      return DaoKind.li;
    case CultivationSessionCategory.shen:
      return DaoKind.zhi;
    case CultivationSessionCategory.gu:
      return DaoKind.lian;
    case CultivationSessionCategory.wudao:
      return DaoKind.none;
    case CultivationSessionCategory.misc:
      return null;
  }
}

/// 每分钟修为（基础）。
const int kSessionXpPerMinute = 2;

/// 每分钟道痕（基础）。
const int kSessionDaoTracePerMinute = 1;

/// 每分钟流派感悟（基础）。
const int kSessionRealmExpPerMinute = 1;

/// 悟道倍率（道痕/感悟均高于普通分类）。
const double kSessionWudaoMultiplier = 3.0;

/// 单次闭关最大分钟数（安全上限，防止极端时长溢出）。
const int kSessionMaxMinutes = 600;
