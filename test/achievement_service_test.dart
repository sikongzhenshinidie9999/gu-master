import 'package:flutter_test/flutter_test.dart';

import 'package:sidequest/src/features/cultivation/data/cultivation_session.dart';
import 'package:sidequest/src/features/cultivation/logic/achievement_service.dart';

CultivationSession makeSession(int minutes,
    {DateTime? start, int? status}) {
  return CultivationSession(
    id: 's$minutes-${start?.millisecondsSinceEpoch}',
    startTime: start ?? DateTime(2026, 8, 24, 9, 0),
    endTime: null,
    plannedDurationMinutes: minutes,
    actualDurationMinutes: minutes,
    subject: '英语',
    category: CultivationSessionCategory.shen.index,
    status: status ?? CultivationSessionStatus.completed.index,
    xpEarned: minutes,
  );
}

List<CultivationSession> manySessions(int count, int minutes,
    {DateTime? start}) {
  return List.generate(count, (i) => makeSession(minutes, start: start));
}

void main() {
  group('computeAchievements', () {
    test('空数据 → 全部未解锁', () {
      final a = computeAchievements([]);
      expect(a.length, 6);
      expect(a.every((x) => !x.isUnlocked), isTrue);
    });

    test('首次闭关：1 次 session → 解锁，其余未解锁', () {
      final a = computeAchievements([makeSession(25)]);
      expect(a.firstWhere((x) => x.id == 'first_session').isUnlocked, isTrue);
      expect(a.where((x) => x.id != 'first_session').every((x) => !x.isUnlocked),
          isTrue);
    });

    test('累计 10 小时 → 初窥修途解锁', () {
      // 600 分钟
      final sessions = manySessions(24, 25); // 600 分钟
      final a = computeAchievements(sessions);
      expect(a.firstWhere((x) => x.id == 'study_10h').isUnlocked, isTrue);
      expect(a.firstWhere((x) => x.id == 'study_50h').isUnlocked, isFalse);
    });

    test('累计 100 小时 → 大道无疆解锁（同时解锁低阶）', () {
      // 6000 分钟
      final sessions = manySessions(240, 25); // 6000 分钟
      final a = computeAchievements(sessions);
      expect(a.firstWhere((x) => x.id == 'first_session').isUnlocked, isTrue);
      expect(a.firstWhere((x) => x.id == 'study_10h').isUnlocked, isTrue);
      expect(a.firstWhere((x) => x.id == 'study_50h').isUnlocked, isTrue);
      expect(a.firstWhere((x) => x.id == 'study_100h').isUnlocked, isTrue);
    });

    test('连续 7 天 → 勤修苦练解锁', () {
      final sessions = List.generate(7, (i) => makeSession(25,
          start: DateTime(2026, 8, 18).add(Duration(days: i))));
      final a = computeAchievements(sessions);
      expect(a.firstWhere((x) => x.id == 'streak_7d').isUnlocked, isTrue);
      expect(a.firstWhere((x) => x.id == 'streak_30d').isUnlocked, isFalse);
    });

    test('连续不足 7 天 → 不解锁', () {
      final sessions = List.generate(6, (i) => makeSession(25,
          start: DateTime(2026, 8, 18).add(Duration(days: i))));
      final a = computeAchievements(sessions);
      expect(a.firstWhere((x) => x.id == 'streak_7d').isUnlocked, isFalse);
    });

    test('多成就：大量短时 + 长连续', () {
      // 每天 25 分钟 × 30 天 → 连续 30 天（持之以恒解锁），累计 750 分钟
      final sessions = List.generate(30, (i) => makeSession(25,
          start: DateTime(2026, 8, 1).add(Duration(days: i))));
      final a = computeAchievements(sessions);
      expect(a.firstWhere((x) => x.id == 'streak_30d').isUnlocked, isTrue);
      expect(a.firstWhere((x) => x.id == 'streak_7d').isUnlocked, isTrue);
      expect(a.firstWhere((x) => x.id == 'study_10h').isUnlocked, isTrue); // 750 ≥ 600
      expect(a.firstWhere((x) => x.id == 'study_50h').isUnlocked, isFalse);
    });

    test('只统计 completed（取消不计）', () {
      final sessions = [
        makeSession(25),
        makeSession(30, status: CultivationSessionStatus.cancelled.index),
      ];
      final a = computeAchievements(sessions);
      expect(a.firstWhere((x) => x.id == 'first_session').isUnlocked, isTrue);
    });
  });
}
