import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:sidequest/src/features/cultivation/data/cultivation_session.dart';
import 'package:sidequest/src/features/cultivation/data/dao.dart';
import 'package:sidequest/src/features/cultivation/data/dao_zhu.dart';
import 'package:sidequest/src/features/cultivation/data/gu_insect.dart';
import 'package:sidequest/src/features/cultivation/data/gu_material.dart';
import 'package:sidequest/src/features/cultivation/data/player_profile.dart';
import 'package:sidequest/src/features/cultivation/data/tribulation_record.dart';
import 'package:sidequest/src/features/cultivation/logic/cultivation_provider.dart';
import 'package:sidequest/src/features/cultivation/logic/cultivation_session_provider.dart';
import 'package:sidequest/src/features/quests/data/quest_model.dart';

/// 固定值 Random，用于确定性控制蛊材掉落。
class _FixedRandom implements Random {
  final double doubleValue;
  _FixedRandom(this.doubleValue);

  @override
  double nextDouble() => doubleValue;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => doubleValue < 0.5;
}

final DateTime _now = DateTime(2026, 8, 24, 10, 0);

void main() {
  // TypeAdapter 全局只注册一次
  Hive.registerAdapter(QuestModelAdapter()); // typeId 0
  Hive.registerAdapter(PlayerProfileAdapter()); // typeId 1
  Hive.registerAdapter(TribulationRecordAdapter()); // typeId 2
  Hive.registerAdapter(GuInsectAdapter()); // typeId 3
  Hive.registerAdapter(GuMaterialAdapter()); // typeId 4
  Hive.registerAdapter(DaoZhuStateAdapter()); // typeId 5
  Hive.registerAdapter(CultivationSessionAdapter()); // typeId 6

  late Directory tempDir;
  late Box<CultivationSession> sessionBox;
  late Box<PlayerProfile> cultivationBox;
  late Box statsBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('session_provider_test_');
    Hive.init(tempDir.path);
    sessionBox = await Hive.openBox<CultivationSession>('sessions');
    cultivationBox = await Hive.openBox<PlayerProfile>('cultivation');
    await Hive.openBox<QuestModel>('quests');
    statsBox = await Hive.openBox('stats');
    await Hive.openBox('settings');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  CultivationSessionNotifier makeNotifier() {
    final cult = CultivationNotifier(cultivationBox, statsBox);
    return CultivationSessionNotifier(sessionBox, statsBox, cult);
  }

  group('CultivationSessionNotifier', () {
    test('startSession 创建 running 记录', () {
      final n = makeNotifier();
      n.startSession(subject: '英语', plannedDurationMinutes: 25, now: _now);
      final s = n.state.currentSession;
      expect(s, isNotNull);
      expect(s!.status, CultivationSessionStatus.running.index);
      expect(s.startTime, _now);
      expect(s.endTime, isNull);
      expect(s.actualDurationMinutes, 0);
      expect(s.xpEarned, 0);
      expect(s.subject, '英语');
      expect(s.category, CultivationSessionCategory.shen.index);
    });

    test('pause/resume 状态变化', () {
      final n = makeNotifier();
      n.startSession(subject: '英语', plannedDurationMinutes: 25, now: _now);
      n.pauseSession();
      expect(n.state.currentSession!.status,
          CultivationSessionStatus.paused.index);
      n.resumeSession();
      expect(n.state.currentSession!.status,
          CultivationSessionStatus.running.index);
    });

    test('completeSession 保存 session 并清空 current', () async {
      final n = makeNotifier();
      n.startSession(subject: '英语', plannedDurationMinutes: 25, now: _now);
      await n.completeSession(
          now: _now.add(const Duration(minutes: 25)),
          random: _FixedRandom(0.0));

      expect(n.state.currentSession, isNull);
      expect(sessionBox.length, 1);
      final stored = sessionBox.values.first;
      expect(stored.status, CultivationSessionStatus.completed.index);
      expect(stored.actualDurationMinutes, 25);
      expect(stored.subject, '英语');
      expect(stored.endTime, _now.add(const Duration(minutes: 25)));
      expect(n.state.todaySessions.length, 1);
      expect(n.todayXp, stored.xpEarned);
    });

    test('completeSession 增加 totalXp（statsBox 唯一权威）', () async {
      final n = makeNotifier();
      n.startSession(subject: '英语', plannedDurationMinutes: 25, now: _now);
      final before = statsBox.get('totalXp', defaultValue: 0) as int;
      await n.completeSession(
          now: _now.add(const Duration(minutes: 25)),
          random: _FixedRandom(0.0));
      final after = statsBox.get('totalXp', defaultValue: 0) as int;
      final xp = sessionBox.values.first.xpEarned;
      expect(xp, greaterThan(0));
      expect(after, before + xp);
    });

    test('completeSession 增加 cultivation 奖励（道痕/感悟）', () async {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final n = CultivationSessionNotifier(sessionBox, statsBox, cult);
      n.startSession(subject: '英语', plannedDurationMinutes: 25, now: _now);
      await n.completeSession(
          now: _now.add(const Duration(minutes: 25)),
          random: _FixedRandom(0.0));
      // 英语 → 炼神 → 智道
      expect(cult.state.profile.daoTraces[DaoKind.zhi.index], greaterThan(0));
      expect(cult.state.profile.factionRealmExp[Faction.zhi.daoKind.index],
          greaterThan(0));
    });

    test('cancel 不奖励', () async {
      final n = makeNotifier();
      n.startSession(subject: '英语', plannedDurationMinutes: 25, now: _now);
      final xpBefore = statsBox.get('totalXp', defaultValue: 0) as int;
      await n.cancelSession(now: _now.add(const Duration(minutes: 5)));

      expect(n.state.currentSession, isNull);
      expect(sessionBox.length, 1);
      final stored = sessionBox.values.first;
      expect(stored.status, CultivationSessionStatus.cancelled.index);
      expect(stored.xpEarned, 0);
      expect(statsBox.get('totalXp', defaultValue: 0) as int, xpBefore);
    });

    test('重复 complete 防护：第二次不重复发奖/不重复保存', () async {
      final n = makeNotifier();
      n.startSession(subject: '英语', plannedDurationMinutes: 25, now: _now);
      await n.completeSession(
          now: _now.add(const Duration(minutes: 25)),
          random: _FixedRandom(0.0));
      final xpAfter1 = statsBox.get('totalXp', defaultValue: 0) as int;
      final boxLen1 = sessionBox.length;

      await n.completeSession(
          now: _now.add(const Duration(minutes: 25)),
          random: _FixedRandom(0.0));
      expect(sessionBox.length, boxLen1); // 不重复保存
      expect(statsBox.get('totalXp', defaultValue: 0) as int, xpAfter1);
    });

    test('todaySessions 与 todayXp 正确统计', () async {
      final n = makeNotifier();
      n.startSession(subject: '英语', plannedDurationMinutes: 25, now: _now);
      await n.completeSession(
          now: _now.add(const Duration(minutes: 25)),
          random: _FixedRandom(0.0));
      n.startSession(subject: '数学', plannedDurationMinutes: 45,
          now: _now.add(const Duration(minutes: 30)));
      await n.completeSession(
          now: _now.add(const Duration(minutes: 75)),
          random: _FixedRandom(0.0));

      expect(n.state.todaySessions.length, 2);
      expect(n.state.todaySessions.map((s) => s.subject),
          containsAll(['英语', '数学']));
      final sum = n.state.todaySessions.fold<int>(0, (acc, s) => acc + s.xpEarned);
      expect(n.todayXp, sum);
    });
  });

  group('学习连续打卡 studyStreak', () {
    test('第一次闭关完成 → studyStreak = 1', () async {
      final n = makeNotifier();
      n.startSession(subject: '英语', plannedDurationMinutes: 25, now: _now);
      await n.completeSession(
          now: _now.add(const Duration(minutes: 25)),
          random: _FixedRandom(0.0));
      expect(statsBox.get('studyStreak'), 1);
      expect(statsBox.get('lastStudyDate'), '2026-08-24');
    });

    test('同一天两次闭关 → streak 不增加', () async {
      final n = makeNotifier();
      n.startSession(subject: '英语', plannedDurationMinutes: 25, now: _now);
      await n.completeSession(
          now: _now.add(const Duration(minutes: 25)),
          random: _FixedRandom(0.0));
      n.startSession(subject: '数学',
          plannedDurationMinutes: 25,
          now: _now.add(const Duration(hours: 2)));
      await n.completeSession(
          now: _now.add(const Duration(hours: 2, minutes: 25)),
          random: _FixedRandom(0.0));
      expect(statsBox.get('studyStreak'), 1);
      expect(statsBox.get('lastStudyDate'), '2026-08-24');
    });

    test('连续两天完成 → streak + 1', () async {
      final n = makeNotifier();
      final day1 = DateTime(2026, 8, 24, 10, 0);
      final day2 = DateTime(2026, 8, 25, 10, 0);
      n.startSession(subject: '英语', plannedDurationMinutes: 25, now: day1);
      await n.completeSession(
          now: day1.add(const Duration(minutes: 25)),
          random: _FixedRandom(0.0));
      n.startSession(subject: '英语', plannedDurationMinutes: 25, now: day2);
      await n.completeSession(
          now: day2.add(const Duration(minutes: 25)),
          random: _FixedRandom(0.0));
      expect(statsBox.get('studyStreak'), 2);
      expect(statsBox.get('lastStudyDate'), '2026-08-25');
    });

    test('断档后重新学习 → streak 重置为 1', () async {
      final n = makeNotifier();
      final day1 = DateTime(2026, 8, 24, 10, 0);
      final day3 = DateTime(2026, 8, 26, 10, 0); // 跳过 8/25
      n.startSession(subject: '英语', plannedDurationMinutes: 25, now: day1);
      await n.completeSession(
          now: day1.add(const Duration(minutes: 25)),
          random: _FixedRandom(0.0));
      n.startSession(subject: '英语', plannedDurationMinutes: 25, now: day3);
      await n.completeSession(
          now: day3.add(const Duration(minutes: 25)),
          random: _FixedRandom(0.0));
      expect(statsBox.get('studyStreak'), 1);
      expect(statsBox.get('lastStudyDate'), '2026-08-26');
    });

    test('取消闭关 → 不增加 streak', () async {
      final n = makeNotifier();
      n.startSession(subject: '英语', plannedDurationMinutes: 25, now: _now);
      await n.cancelSession(now: _now.add(const Duration(minutes: 5)));
      expect(statsBox.get('studyStreak'), isNull);
      expect(statsBox.get('lastStudyDate'), isNull);
      expect(sessionBox.length, 1); // 仅 cancelled 记录
    });

    test('旧数据不存在 → 安全初始化', () async {
      // statsBox 无 studyStreak / lastStudyDate
      final n = makeNotifier();
      n.startSession(subject: '英语', plannedDurationMinutes: 25, now: _now);
      await n.completeSession(
          now: _now.add(const Duration(minutes: 25)),
          random: _FixedRandom(0.0));
      expect(statsBox.get('studyStreak'), 1);
      expect(statsBox.get('lastStudyDate'), '2026-08-24');
    });
  });
}
