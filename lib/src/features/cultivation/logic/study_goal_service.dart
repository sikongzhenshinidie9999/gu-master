// 今日学习目标 —— 纯逻辑（从 sessions 派生今日学习分钟 + 进度计算）。

import '../data/cultivation_session.dart';

/// 今日已完成（completed）的学习分钟。
///
/// 只统计 [now] 当天的 completed 记录；取消/未完成不计。
int getTodayStudyMinutes(List<CultivationSession> sessions, DateTime now) {
  var total = 0;
  for (final s in sessions) {
    if (s.status != CultivationSessionStatus.completed.index) continue;
    if (_isSameDay(s.startTime, now)) {
      total += s.actualDurationMinutes;
    }
  }
  return total;
}

/// 目标进度（0~100 百分比；截断取整，超过目标封顶 100）。
int calculateGoalProgress({required int current, required int goal}) {
  if (goal <= 0) return 0;
  final pct = (current * 100) ~/ goal;
  if (pct > 100) return 100;
  if (pct < 0) return 0;
  return pct;
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
