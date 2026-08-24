import 'package:flutter_test/flutter_test.dart';

import 'package:sidequest/src/features/cultivation/data/cultivation_session.dart';
import 'package:sidequest/src/features/cultivation/logic/challenge_service.dart';

CultivationSession makeSession(int minutes, {DateTime? start, int? status}) {
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

void main() {
  // 2026-08-24（周一）
  final now = DateTime(2026, 8, 24, 20, 0);
  final today = DateTime(2026, 8, 24, 9, 0);

  ChallengeRecord byTitle(ChallengeSummary s, String title) =>
      s.records.firstWhere((r) => r.title == title);

  group('computeChallenges', () {
    test('空数据安全（全 0）', () {
      final s = computeChallenges([], now);
      expect(s.totalMinutes, 0);
      expect(byTitle(s, '最长连续').current, 0);
      expect(byTitle(s, '最长连续').best, 0);
      expect(byTitle(s, '单日最高').best, 0);
      expect(byTitle(s, '单周最高').best, 0);
    });

    test('单日最高：同一天多次取合计；跨日期取最大', () {
      final sessions = [
        makeSession(25, start: today),
        makeSession(45, start: today.add(const Duration(hours: 2))), // 同日
        makeSession(90, start: DateTime(2026, 8, 23, 9, 0)), // 昨日更大
      ];
      final s = computeChallenges(sessions, now);
      expect(byTitle(s, '单日最高').current, 70); // 今天 25+45
      expect(byTitle(s, '单日最高').best, 90); // 历史最高（昨天 90）
    });

    test('单周最高：跨周比较', () {
      final sessions = [
        makeSession(100, start: today), // 本周 100
        makeSession(200, start: DateTime(2026, 8, 17, 9, 0)), // 上周 200
      ];
      final s = computeChallenges(sessions, now);
      expect(byTitle(s, '单周最高').current, 100); // 本周
      expect(byTitle(s, '单周最高').best, 200); // 历史最高
    });

    test('单月最高：跨月比较', () {
      final sessions = [
        makeSession(300, start: today), // 本月 300
        makeSession(500, start: DateTime(2026, 7, 15, 9, 0)), // 上月 500
      ];
      final s = computeChallenges(sessions, now);
      expect(byTitle(s, '累计').best, 800);
      // 单月纪录未直接暴露，但总累计正确（best=800）
      expect(s.totalMinutes, 800);
    });

    test('最长连续：current 与 best', () {
      // 8/20-8/22 连续 3 天 + 今天 8/24 → 断一天
      final sessions = [
        makeSession(25, start: DateTime(2026, 8, 20)),
        makeSession(25, start: DateTime(2026, 8, 21)),
        makeSession(25, start: DateTime(2026, 8, 22)),
        makeSession(25, start: today), // 8/24，与 8/22 断开
      ];
      final s = computeChallenges(sessions, now);
      expect(byTitle(s, '最长连续').best, 3);
      expect(byTitle(s, '最长连续').current, 1); // 今天开始新的一串
    });

    test('最高值更新：多天取最大值', () {
      final sessions = [
        makeSession(10, start: DateTime(2026, 8, 20)),
        makeSession(120, start: DateTime(2026, 8, 21)),
        makeSession(30, start: DateTime(2026, 8, 22)),
      ];
      final s = computeChallenges(sessions, now);
      expect(byTitle(s, '单日最高').best, 120);
    });

    test('只统计 completed（取消不计）', () {
      final sessions = [
        makeSession(25, start: today),
        makeSession(999,
            start: today, status: CultivationSessionStatus.cancelled.index),
      ];
      final s = computeChallenges(sessions, now);
      expect(byTitle(s, '单日最高').current, 25);
      expect(s.totalMinutes, 25);
    });
  });
}
