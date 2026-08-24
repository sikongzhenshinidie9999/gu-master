// 学习统计 —— 纯逻辑（今日/本周/累计聚合，从 sessions 派生）。

import '../data/cultivation_session.dart';

/// 学习统计数据（纯数据；studyStreak 由 Provider 从 statsBox 填充）。
class StudyStatistics {
  const StudyStatistics({
    required this.todayStudyMinutes,
    required this.todaySessionCount,
    required this.todayXp,
    required this.weeklyStudyMinutes,
    required this.weeklySessionCount,
    required this.totalStudyMinutes,
    required this.totalSessionCount,
    this.studyStreak = 0,
  });

  final int todayStudyMinutes;
  final int todaySessionCount;
  final int todayXp;
  final int weeklyStudyMinutes;
  final int weeklySessionCount;
  final int totalStudyMinutes;
  final int totalSessionCount;

  /// 连续学习天数（非 session 派生，由 Provider 从 statsBox 读取）。
  final int studyStreak;

  StudyStatistics copyWith({int? studyStreak}) {
    return StudyStatistics(
      todayStudyMinutes: todayStudyMinutes,
      todaySessionCount: todaySessionCount,
      todayXp: todayXp,
      weeklyStudyMinutes: weeklyStudyMinutes,
      weeklySessionCount: weeklySessionCount,
      totalStudyMinutes: totalStudyMinutes,
      totalSessionCount: totalSessionCount,
      studyStreak: studyStreak ?? this.studyStreak,
    );
  }
}

/// 计算学习统计（纯函数；只统计 completed 记录）。
///
/// - 今日：与 [now] 同一天；
/// - 本周：周一起始；
/// - 累计：全部。
StudyStatistics computeStudyStatistics(
    List<CultivationSession> sessions, DateTime now) {
  var todayMinutes = 0, todayCount = 0, todayXp = 0;
  var weekMinutes = 0, weekCount = 0;
  var totalMinutes = 0, totalCount = 0;

  final dayStart = DateTime(now.year, now.month, now.day);
  final weekStart = dayStart.subtract(Duration(days: now.weekday - 1));

  for (final s in sessions) {
    if (s.status != CultivationSessionStatus.completed.index) continue;
    totalMinutes += s.actualDurationMinutes;
    totalCount++;
    if (_isSameDay(s.startTime, now)) {
      todayMinutes += s.actualDurationMinutes;
      todayCount++;
      todayXp += s.xpEarned;
    }
    if (!s.startTime.isBefore(weekStart)) {
      weekMinutes += s.actualDurationMinutes;
      weekCount++;
    }
  }

  return StudyStatistics(
    todayStudyMinutes: todayMinutes,
    todaySessionCount: todayCount,
    todayXp: todayXp,
    weeklyStudyMinutes: weekMinutes,
    weeklySessionCount: weekCount,
    totalStudyMinutes: totalMinutes,
    totalSessionCount: totalCount,
  );
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
