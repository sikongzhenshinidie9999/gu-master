import 'package:flutter_test/flutter_test.dart';

import 'package:sidequest/src/features/cultivation/data/cultivation_session.dart';
import 'package:sidequest/src/features/cultivation/logic/study_goal_service.dart';

CultivationSession makeSession(int minutes,
    {DateTime? start, int? status}) {
  return CultivationSession(
    id: 's$minutes',
    startTime: start ?? DateTime(2026, 8, 24, 9, 0),
    endTime: null,
    plannedDurationMinutes: minutes,
    actualDurationMinutes: minutes,
    subject: '英语',
    category: CultivationSessionCategory.shen.index,
    status: status ?? CultivationSessionStatus.completed.index,
  );
}

void main() {
  group('getTodayStudyMinutes', () {
    test('今日 completed 分钟统计', () {
      final now = DateTime(2026, 8, 24, 20, 0);
      final sessions = [
        makeSession(25, start: DateTime(2026, 8, 24, 9, 0)),
        makeSession(45, start: DateTime(2026, 8, 24, 14, 0)),
      ];
      expect(getTodayStudyMinutes(sessions, now), 70);
    });

    test('跨日期不统计', () {
      final now = DateTime(2026, 8, 24, 20, 0);
      final sessions = [
        makeSession(25, start: DateTime(2026, 8, 24, 9, 0)), // 今天
        makeSession(45, start: DateTime(2026, 8, 23, 9, 0)), // 昨天
        makeSession(90, start: DateTime(2026, 8, 25, 9, 0)), // 明天
      ];
      expect(getTodayStudyMinutes(sessions, now), 25);
    });

    test('只统计 completed（取消不计）', () {
      final now = DateTime(2026, 8, 24, 20, 0);
      final sessions = [
        makeSession(25, start: DateTime(2026, 8, 24, 9, 0)),
        makeSession(
          30,
          start: DateTime(2026, 8, 24, 10, 0),
          status: CultivationSessionStatus.cancelled.index,
        ),
      ];
      expect(getTodayStudyMinutes(sessions, now), 25);
    });
  });

  group('calculateGoalProgress', () {
    test('45/120 → 37%', () {
      expect(calculateGoalProgress(current: 45, goal: 120), 37);
    });

    test('达到目标 → 100%', () {
      expect(calculateGoalProgress(current: 120, goal: 120), 100);
    });

    test('超过目标 → 封顶 100%', () {
      expect(calculateGoalProgress(current: 150, goal: 120), 100);
    });

    test('0 分钟 → 0%；goal<=0 安全', () {
      expect(calculateGoalProgress(current: 0, goal: 120), 0);
      expect(calculateGoalProgress(current: 50, goal: 0), 0);
    });
  });
}
