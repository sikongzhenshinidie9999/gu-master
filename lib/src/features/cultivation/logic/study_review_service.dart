// 周/月/近7日/学科 学习回顾 —— 纯逻辑（只统计 completed session）。

import '../data/cultivation_session.dart';

/// 单日学习记录。
class DailyStudyRecord {
  const DailyStudyRecord({
    required this.date,
    required this.minutes,
    required this.sessionCount,
    required this.xp,
  });

  final DateTime date;
  final int minutes;
  final int sessionCount;
  final int xp;
}

/// 学习回顾（纯数据）。
class StudyReview {
  const StudyReview({
    required this.weeklyMinutes,
    required this.weeklySessionCount,
    required this.weeklyXp,
    required this.monthlyMinutes,
    required this.monthlySessionCount,
    required this.monthlyXp,
    required this.last7Days,
    required this.subjectMinutes,
  });

  final int weeklyMinutes;
  final int weeklySessionCount;
  final int weeklyXp;
  final int monthlyMinutes;
  final int monthlySessionCount;
  final int monthlyXp;

  /// 最近 7 天（含今天，index 0 = 今天），每天一条。
  final List<DailyStudyRecord> last7Days;

  /// 学科 → 累计分钟。
  final Map<String, int> subjectMinutes;
}

/// 计算学习回顾（纯函数）。
StudyReview computeStudyReview(
    List<CultivationSession> sessions, DateTime now) {
  var weeklyMinutes = 0, weeklyCount = 0, weeklyXp = 0;
  var monthlyMinutes = 0, monthlyCount = 0, monthlyXp = 0;

  final dayStart = DateTime(now.year, now.month, now.day);
  final weekStart = dayStart.subtract(Duration(days: now.weekday - 1));

  final subjectMinutes = <String, int>{};
  final dayAgg = <DateTime, List<int>>{};

  for (final s in sessions) {
    if (s.status != CultivationSessionStatus.completed.index) continue;
    final d = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);

    if (!s.startTime.isBefore(weekStart)) {
      weeklyMinutes += s.actualDurationMinutes;
      weeklyCount++;
      weeklyXp += s.xpEarned;
    }
    if (s.startTime.year == now.year && s.startTime.month == now.month) {
      monthlyMinutes += s.actualDurationMinutes;
      monthlyCount++;
      monthlyXp += s.xpEarned;
    }
    subjectMinutes[s.subject] =
        (subjectMinutes[s.subject] ?? 0) + s.actualDurationMinutes;

    final agg = dayAgg.putIfAbsent(d, () => [0, 0, 0]);
    agg[0] += s.actualDurationMinutes;
    agg[1]++;
    agg[2] += s.xpEarned;
  }

  final last7 = <DailyStudyRecord>[];
  for (var i = 0; i < 7; i++) {
    final d = dayStart.subtract(Duration(days: i));
    final agg = dayAgg[d] ?? const [0, 0, 0];
    last7.add(DailyStudyRecord(
      date: d,
      minutes: agg[0],
      sessionCount: agg[1],
      xp: agg[2],
    ));
  }

  // 学科按分钟降序，便于展示
  final sortedSubjects = subjectMinutes.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final subjectMap = <String, int>{};
  for (final e in sortedSubjects) {
    subjectMap[e.key] = e.value;
  }

  return StudyReview(
    weeklyMinutes: weeklyMinutes,
    weeklySessionCount: weeklyCount,
    weeklyXp: weeklyXp,
    monthlyMinutes: monthlyMinutes,
    monthlySessionCount: monthlyCount,
    monthlyXp: monthlyXp,
    last7Days: last7,
    subjectMinutes: subjectMap,
  );
}

/// 最长连续学习天数（completed 记录去重学习日；供成就/挑战复用）。
int longestStudyStreak(List<CultivationSession> sessions) {
  final days = <DateTime>{};
  for (final s in sessions) {
    if (s.status != CultivationSessionStatus.completed.index) continue;
    days.add(DateTime(s.startTime.year, s.startTime.month, s.startTime.day));
  }
  final sorted = days.toList()..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final d in sorted) {
    run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }
  return best;
}

/// 当前连续学习天数（截至今天；今天未学但昨天学则延续）。
int currentStudyStreak(List<CultivationSession> sessions, DateTime now) {
  final days = <DateTime>{};
  for (final s in sessions) {
    if (s.status != CultivationSessionStatus.completed.index) continue;
    days.add(DateTime(s.startTime.year, s.startTime.month, s.startTime.day));
  }
  final today = DateTime(now.year, now.month, now.day);
  var cursor = days.contains(today) ? today : today.subtract(const Duration(days: 1));
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}
