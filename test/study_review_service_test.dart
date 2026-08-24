import 'package:flutter_test/flutter_test.dart';

import 'package:sidequest/src/features/cultivation/data/cultivation_session.dart';
import 'package:sidequest/src/features/cultivation/logic/study_review_service.dart';

CultivationSession makeSession(int minutes,
    {DateTime? start, int? status, int xp = 0, String subject = '英语'}) {
  return CultivationSession(
    id: 's$minutes-${start?.millisecondsSinceEpoch}-$subject',
    startTime: start ?? DateTime(2026, 8, 24, 9, 0),
    endTime: null,
    plannedDurationMinutes: minutes,
    actualDurationMinutes: minutes,
    subject: subject,
    category: CultivationSessionCategory.shen.index,
    status: status ?? CultivationSessionStatus.completed.index,
    xpEarned: xp,
  );
}

void main() {
  // 2026-08-24（周一）
  final now = DateTime(2026, 8, 24, 20, 0);
  final today = DateTime(2026, 8, 24, 9, 0);
  final lastSunday = DateTime(2026, 8, 23, 9, 0); // 上周日
  final lastMonth = DateTime(2026, 7, 30, 9, 0); // 上月

  group('computeStudyReview', () {
    test('周统计（本周含本周另一天、排除上周）', () {
      final dayStart = DateTime(now.year, now.month, now.day);
      final weekStart = dayStart.subtract(Duration(days: now.weekday - 1));
      final thisWeekOther = weekStart.add(const Duration(days: 1));
      final lastWeek = weekStart.subtract(const Duration(days: 1));
      final sessions = [
        makeSession(25, start: today, xp: 25),
        makeSession(45, start: thisWeekOther, xp: 45),
        makeSession(90, start: lastWeek), // 不计本周
      ];
      final r = computeStudyReview(sessions, now);
      expect(r.weeklyMinutes, 70);
      expect(r.weeklySessionCount, 2);
      expect(r.weeklyXp, 70);
    });

    test('月统计（本月，排除上月）', () {
      final sessions = [
        makeSession(25, start: today),
        makeSession(45, start: lastSunday),
        makeSession(90, start: lastMonth), // 不计本月
      ];
      final r = computeStudyReview(sessions, now);
      expect(r.monthlyMinutes, 70);
      expect(r.monthlySessionCount, 2);
    });

    test('最近 7 日趋势（index 0 = 今天，含 0 日）', () {
      final sessions = [
        makeSession(25, start: today),
        makeSession(45, start: DateTime(2026, 8, 22, 9, 0)), // 2 天前
      ];
      final r = computeStudyReview(sessions, now);
      expect(r.last7Days.length, 7);
      expect(r.last7Days[0].date, DateTime(2026, 8, 24));
      expect(r.last7Days[0].minutes, 25);
      expect(r.last7Days[2].minutes, 45);
      expect(r.last7Days[1].minutes, 0); // 昨天无记录
    });

    test('学科统计（累计分钟，按分钟降序）', () {
      final sessions = [
        makeSession(25, start: today, subject: '数学'),
        makeSession(45, start: today, subject: '英语'),
        makeSession(10, start: today, subject: '数学'),
      ];
      final r = computeStudyReview(sessions, now);
      expect(r.subjectMinutes['数学'], 35);
      expect(r.subjectMinutes['英语'], 45);
      expect(r.subjectMinutes.keys.first, '英语'); // 降序
    });

    test('只统计 completed（取消不计）', () {
      final sessions = [
        makeSession(25, start: today),
        makeSession(30, start: today, status: CultivationSessionStatus.cancelled.index),
      ];
      final r = computeStudyReview(sessions, now);
      expect(r.weeklyMinutes, 25);
      expect(r.monthlyMinutes, 25);
    });

    test('空数据安全（全 0）', () {
      final r = computeStudyReview([], now);
      expect(r.weeklyMinutes, 0);
      expect(r.weeklySessionCount, 0);
      expect(r.monthlyMinutes, 0);
      expect(r.last7Days.length, 7);
      expect(r.last7Days.every((d) => d.minutes == 0), isTrue);
      expect(r.subjectMinutes, isEmpty);
    });
  });

  group('连续学习天数辅助', () {
    test('longestStudyStreak', () {
      final sessions = [
        makeSession(25, start: DateTime(2026, 8, 20)),
        makeSession(25, start: DateTime(2026, 8, 21)),
        makeSession(25, start: DateTime(2026, 8, 22)),
        makeSession(25, start: DateTime(2026, 8, 24)), // 断一天后
        makeSession(25, start: DateTime(2026, 8, 25)),
      ];
      expect(longestStudyStreak(sessions), 3);
    });

    test('currentStudyStreak（今天已学 → 连续到今天）', () {
      final sessions = [
        makeSession(25, start: DateTime(2026, 8, 22)),
        makeSession(25, start: DateTime(2026, 8, 23)),
        makeSession(25, start: DateTime(2026, 8, 24, 9)),
      ];
      expect(currentStudyStreak(sessions, now), 3);
    });

    test('currentStudyStreak（今天未学但昨天学 → 延续）', () {
      final sessions = [
        makeSession(25, start: DateTime(2026, 8, 23)),
      ];
      expect(currentStudyStreak(sessions, now), 1);
    });
  });
}
