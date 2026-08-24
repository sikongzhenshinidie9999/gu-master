// 成就系统 —— 纯逻辑（从 sessions 派生，不新增 Hive schema）。

import '../data/cultivation_session.dart';
import 'study_review_service.dart';

/// 成就（纯数据）。
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.isUnlocked,
  });

  final String id;
  final String title;
  final String description;
  final bool isUnlocked;
}

/// 计算成就解锁状态（纯函数；只统计 completed session）。
///
/// - 首次闭关：完成 ≥ 1 次闭关；
/// - 初窥修途：累计学习 ≥ 10 小时（600 分钟）；
/// - 百炼成钢：累计学习 ≥ 50 小时（3000 分钟）；
/// - 勤修苦练：最长连续学习 ≥ 7 天；
/// - 持之以恒：最长连续学习 ≥ 30 天；
/// - 大道无疆：累计学习 ≥ 100 小时（6000 分钟）。
List<Achievement> computeAchievements(List<CultivationSession> sessions) {
  var totalMinutes = 0, totalCount = 0;
  for (final s in sessions) {
    if (s.status != CultivationSessionStatus.completed.index) continue;
    totalMinutes += s.actualDurationMinutes;
    totalCount++;
  }
  final longest = longestStudyStreak(sessions);

  return [
    Achievement(
      id: 'first_session',
      title: '首次闭关',
      description: '完成 1 次闭关',
      isUnlocked: totalCount >= 1,
    ),
    Achievement(
      id: 'study_10h',
      title: '初窥修途',
      description: '累计学习 10 小时',
      isUnlocked: totalMinutes >= 600,
    ),
    Achievement(
      id: 'study_50h',
      title: '百炼成钢',
      description: '累计学习 50 小时',
      isUnlocked: totalMinutes >= 3000,
    ),
    Achievement(
      id: 'streak_7d',
      title: '勤修苦练',
      description: '连续学习 7 天',
      isUnlocked: longest >= 7,
    ),
    Achievement(
      id: 'streak_30d',
      title: '持之以恒',
      description: '连续学习 30 天',
      isUnlocked: longest >= 30,
    ),
    Achievement(
      id: 'study_100h',
      title: '大道无疆',
      description: '累计学习 100 小时',
      isUnlocked: totalMinutes >= 6000,
    ),
  ];
}
