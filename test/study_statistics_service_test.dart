import 'package:flutter_test/flutter_test.dart';

import 'package:sidequest/src/features/cultivation/data/cultivation_session.dart';
import 'package:sidequest/src/features/cultivation/logic/study_statistics_service.dart';

CultivationSession makeSession(int minutes,
    {DateTime? start, int? status, int xp = 0}) {
  return CultivationSession(
    id: 's$minutes-${start?.millisecondsSinceEpoch}',
    startTime: start ?? DateTime(2026, 8, 24, 9, 0),
    endTime: null,
    plannedDurationMinutes: minutes,
    actualDurationMinutes: minutes,
    subject: '英语',
    category: CultivationSessionCategory.shen.index,
    status: status ?? CultivationSessionStatus.completed.index,
    xpEarned: xp,
  );
}

void main() {
  final now = DateTime(2026, 8, 24, 20, 0); // 周一（2026-08-24 是周一）
  final today = DateTime(2026, 8, 24, 9, 0);
  final yesterday = DateTime(2026, 8, 23, 9, 0); // 上周日（本周一 = 8/24）
  final lastWeek = DateTime(2026, 8, 17, 9, 0); // 上周一

  group('computeStudyStatistics', () {
    test('今日统计（分钟/次数/修为）', () {
      final sessions = [
        makeSession(25, start: today, xp: 50),
        makeSession(45, start: today, xp: 90),
      ];
      final s = computeStudyStatistics(sessions, now);
      expect(s.todayStudyMinutes, 70);
      expect(s.todaySessionCount, 2);
      expect(s.todayXp, 140);
    });

    test('本周统计（含本周、排除上周）', () {
      final sessions = [
        makeSession(25, start: today), // 本周一
        makeSession(45, start: yesterday), // 上周日 → 不计本周
        makeSession(90, start: lastWeek), // 上周一 → 不计本周
      ];
      final s = computeStudyStatistics(sessions, now);
      expect(s.weeklyStudyMinutes, 25);
      expect(s.weeklySessionCount, 1);
    });

    test('累计统计（全部 completed）', () {
      final sessions = [
        makeSession(25, start: today),
        makeSession(45, start: yesterday),
        makeSession(90, start: lastWeek),
      ];
      final s = computeStudyStatistics(sessions, now);
      expect(s.totalStudyMinutes, 160);
      expect(s.totalSessionCount, 3);
    });

    test('跨日期过滤：今日只统计当天 completed', () {
      final sessions = [
        makeSession(25, start: today),
        makeSession(45, start: yesterday),
        makeSession(30, start: today, status: CultivationSessionStatus.cancelled.index),
      ];
      final s = computeStudyStatistics(sessions, now);
      expect(s.todayStudyMinutes, 25);
      expect(s.todaySessionCount, 1);
    });

    test('空数据安全（全 0）', () {
      final s = computeStudyStatistics([], now);
      expect(s.todayStudyMinutes, 0);
      expect(s.todaySessionCount, 0);
      expect(s.todayXp, 0);
      expect(s.weeklyStudyMinutes, 0);
      expect(s.weeklySessionCount, 0);
      expect(s.totalStudyMinutes, 0);
      expect(s.totalSessionCount, 0);
      expect(s.studyStreak, 0);
    });
  });
}
