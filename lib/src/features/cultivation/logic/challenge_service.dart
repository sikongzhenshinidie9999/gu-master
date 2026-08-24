// 个人挑战（替代多人排行榜）—— 纯逻辑，个人历史最高纪录。

import '../data/cultivation_session.dart';
import 'study_review_service.dart';

/// 单条挑战纪录（纯数据）。
class ChallengeRecord {
  const ChallengeRecord({
    required this.title,
    required this.current,
    required this.best,
  });

  final String title;
  final int current;
  final int best;
}

/// 个人挑战汇总（纯数据）。
class ChallengeSummary {
  const ChallengeSummary({required this.records, required this.totalMinutes});

  final List<ChallengeRecord> records;

  /// 累计学习分钟（展示用）。
  final int totalMinutes;
}

/// 计算个人挑战（纯函数；只统计 completed session）。
///
/// 纪录：
/// - 最长连续：current = 当前连续天数，best = 历史最长；
/// - 单日最高：current = 今日分钟，best = 历史单日最高；
/// - 单周最高：current = 本周分钟，best = 历史单周最高；
/// - 累计：current = 累计分钟，best = 累计分钟。
ChallengeSummary computeChallenges(
    List<CultivationSession> sessions, DateTime now) {
  var totalMinutes = 0;
  var bestDaily = 0;
  final dayMinutes = <DateTime, int>{};
  final weekMinutes = <DateTime, int>{};
  final monthMinutes = <String, int>{};

  for (final s in sessions) {
    if (s.status != CultivationSessionStatus.completed.index) continue;
    totalMinutes += s.actualDurationMinutes;

    final d = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
    final dm = (dayMinutes[d] ?? 0) + s.actualDurationMinutes;
    dayMinutes[d] = dm;
    if (dm > bestDaily) bestDaily = dm;

    final weekStart = d.subtract(Duration(days: s.startTime.weekday - 1));
    weekMinutes[weekStart] =
        (weekMinutes[weekStart] ?? 0) + s.actualDurationMinutes;

    final mKey = '${s.startTime.year}-${s.startTime.month}';
    monthMinutes[mKey] =
        (monthMinutes[mKey] ?? 0) + s.actualDurationMinutes;
  }

  var bestWeekly = 0;
  for (final v in weekMinutes.values) {
    if (v > bestWeekly) bestWeekly = v;
  }
  var bestMonthly = 0;
  for (final v in monthMinutes.values) {
    if (v > bestMonthly) bestMonthly = v;
  }

  final today = DateTime(now.year, now.month, now.day);
  final todayMinutes = dayMinutes[today] ?? 0;
  final weekStartNow = today.subtract(Duration(days: now.weekday - 1));
  final thisWeek = weekMinutes[weekStartNow] ?? 0;

  return ChallengeSummary(
    totalMinutes: totalMinutes,
    records: [
      ChallengeRecord(
        title: '最长连续',
        current: currentStudyStreak(sessions, now),
        best: longestStudyStreak(sessions),
      ),
      ChallengeRecord(
        title: '单日最高',
        current: todayMinutes,
        best: bestDaily,
      ),
      ChallengeRecord(
        title: '单周最高',
        current: thisWeek,
        best: bestWeekly,
      ),
      ChallengeRecord(
        title: '累计',
        current: totalMinutes,
        best: totalMinutes,
      ),
    ],
  );
}
