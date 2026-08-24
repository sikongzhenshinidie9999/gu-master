import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:sidequest/src/features/cultivation/data/dao.dart';
import 'package:sidequest/src/features/cultivation/data/dao_zhu.dart';
import 'package:sidequest/src/features/cultivation/data/gu_insect.dart';
import 'package:sidequest/src/features/cultivation/data/gu_material.dart';
import 'package:sidequest/src/features/cultivation/data/player_profile.dart';
import 'package:sidequest/src/features/cultivation/data/tribulation_record.dart';
import 'package:sidequest/src/features/cultivation/logic/cultivation_provider.dart';
import 'package:sidequest/src/features/cultivation/logic/tribulation_service.dart';
import 'package:sidequest/src/features/quests/data/quest_model.dart';

/// 固定值 Random，用于确定性控制成功/失败。
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

final DateTime _t0 = DateTime(2026, 8, 24, 12, 0);

void _seedRecord(
  CultivationNotifier cult,
  int realmLevel,
  int stageIndex, {
  int failCount = 0,
  DateTime? lastAttemptAt,
}) {
  cult.state.profile.tribulations.add(TribulationRecord(
    realmLevel: realmLevel,
    stageIndex: stageIndex,
    failCount: failCount,
    lastAttemptAt: lastAttemptAt,
  ));
}

void main() {
  // TypeAdapter 全局只注册一次
  Hive.registerAdapter(QuestModelAdapter()); // typeId 0
  Hive.registerAdapter(PlayerProfileAdapter()); // typeId 1
  Hive.registerAdapter(TribulationRecordAdapter()); // typeId 2
  Hive.registerAdapter(GuInsectAdapter()); // typeId 3
  Hive.registerAdapter(GuMaterialAdapter()); // typeId 4
  Hive.registerAdapter(DaoZhuStateAdapter()); // typeId 5

  late Directory tempDir;
  late Box<PlayerProfile> cultivationBox;
  late Box statsBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tribulation_test_');
    Hive.init(tempDir.path);
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

  group('attemptTribulation Provider', () {
    test('成功推进 stage：写入 (6,1) 记录，failCount 0', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final r = cult.attemptTribulation(
          realmLevel: 6, stageIndex: 0, now: _t0, random: _FixedRandom(0.0));
      expect(r.success, isTrue);
      final recs = cult.state.profile.tribulations;
      expect(recs.length, 1);
      expect(recs.first.realmLevel, 6);
      expect(recs.first.stageIndex, 1);
      expect(recs.first.failCount, 0);
      expect(recs.first.lastAttemptAt, _t0);
    });

    test('第三阶段成功产生 stage 3 完成记录（唯一）', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      expect(
        cult
            .attemptTribulation(realmLevel: 6, stageIndex: 0, now: _t0,
                random: _FixedRandom(0.0))
            .success,
        isTrue,
      );
      expect(
        cult
            .attemptTribulation(
                realmLevel: 6,
                stageIndex: 1,
                now: _t0.add(const Duration(hours: 25)),
                random: _FixedRandom(0.0))
            .success,
        isTrue,
      );
      final r3 = cult.attemptTribulation(
          realmLevel: 6,
          stageIndex: 2,
          now: _t0.add(const Duration(hours: 50)),
          random: _FixedRandom(0.0));
      expect(r3.success, isTrue);
      expect(r3.nextStageIndex, 3);
      final recs = cult.state.profile.tribulations;
      expect(recs.length, 1);
      expect(recs.first.stageIndex, 3);
    });

    test('失败 failCount++', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final r = cult.attemptTribulation(
          realmLevel: 6, stageIndex: 0, now: _t0, random: _FixedRandom(1.0));
      expect(r.success, isFalse);
      expect(r.failCount, 1);
      final recs = cult.state.profile.tribulations;
      expect(recs.length, 1);
      expect(recs.first.stageIndex, 0);
      expect(recs.first.failCount, 1);
      expect(recs.first.lastAttemptAt, _t0);
    });

    test('失败扣 currentCultivation（目标转数跨度/3）', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      cult.state.profile.currentCultivation = 5000;
      final r = cult.attemptTribulation(
          realmLevel: 6, stageIndex: 0, now: _t0, random: _FixedRandom(1.0));
      expect(r.success, isFalse);
      // 六转跨度 = kRealms[6]-kRealms[5] = 2500-1500 = 1000 → 惩罚 333
      expect(r.cultivationPenalty, 333);
      expect(cult.state.profile.currentCultivation, 5000 - 333);
    });

    test('currentCultivation 不低于 0', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      cult.state.profile.currentCultivation = 100;
      final r = cult.attemptTribulation(
          realmLevel: 6, stageIndex: 0, now: _t0, random: _FixedRandom(1.0));
      expect(r.success, isFalse);
      expect(cult.state.profile.currentCultivation, 0);
    });

    test('totalXp / daoTraces / factionRealmExp 不变', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final p = cult.state.profile;
      p.totalXp = 5000;
      p.daoTraces[DaoKind.li.index] = 123;
      p.factionRealmExp[Faction.li.daoKind.index] = 456;
      final r = cult.attemptTribulation(
          realmLevel: 6, stageIndex: 0, now: _t0, random: _FixedRandom(1.0));
      expect(r.success, isFalse);
      expect(p.totalXp, 5000);
      expect(p.daoTraces[DaoKind.li.index], 123);
      expect(p.factionRealmExp[Faction.li.daoKind.index], 456);
    });

    test('成功后进入冷却，重复尝试被阻止', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final r1 = cult.attemptTribulation(
          realmLevel: 6, stageIndex: 0, now: _t0, random: _FixedRandom(0.0));
      expect(r1.success, isTrue);
      final r2 = cult.attemptTribulation(
          realmLevel: 6, stageIndex: 1, now: _t0, random: _FixedRandom(0.0));
      expect(r2.outcome, TribulationOutcome.onCooldown);
      // 状态未变：仍只有 (6,1) 一条记录
      expect(cult.state.profile.tribulations.length, 1);
    });

    test('失败后进入冷却，重复尝试被阻止', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final r1 = cult.attemptTribulation(
          realmLevel: 6, stageIndex: 0, now: _t0, random: _FixedRandom(1.0));
      expect(r1.success, isFalse);
      final r2 = cult.attemptTribulation(
          realmLevel: 6, stageIndex: 0, now: _t0, random: _FixedRandom(1.0));
      expect(r2.outcome, TribulationOutcome.onCooldown);
      expect(cult.state.profile.tribulations.single.failCount, 1);
    });

    test('冷却到期允许再次尝试', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final r1 = cult.attemptTribulation(
          realmLevel: 6, stageIndex: 0, now: _t0, random: _FixedRandom(1.0));
      expect(r1.success, isFalse);
      final r2 = cult.attemptTribulation(
          realmLevel: 6,
          stageIndex: 0,
          now: _t0.add(const Duration(hours: 25)),
          random: _FixedRandom(0.0));
      expect(r2.outcome, TribulationOutcome.success);
      expect(cult.state.profile.tribulations.single.stageIndex, 1);
    });

    test('九转尊者劫成功：写入 (9,3) 记录', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final r = cult.attemptTribulation(
          realmLevel: 9, stageIndex: 0, now: _t0, random: _FixedRandom(0.0));
      expect(r.success, isTrue);
      expect(r.tribulationType, TribulationType.venerable);
      final recs = cult.state.profile.tribulations;
      expect(recs.length, 1);
      expect(recs.first.realmLevel, 9);
      expect(recs.first.stageIndex, 3);
    });

    test('九转尊者劫成功不自动 nineTurnReached', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final r = cult.attemptTribulation(
          realmLevel: 9, stageIndex: 0, now: _t0, random: _FixedRandom(0.0));
      expect(r.success, isTrue);
      expect(cult.state.profile.nineTurnReached, isFalse);
      expect(cult.state.profile.nineTurnBreakthroughAt, isNull);
    });

    test('九转尊者劫成功不修改 xianYuan', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      cult.state.profile.xianYuan = XianYuanType.baili.index;
      final r = cult.attemptTribulation(
          realmLevel: 9, stageIndex: 0, now: _t0, random: _FixedRandom(0.0));
      expect(r.success, isTrue);
      expect(cult.state.profile.xianYuan, XianYuanType.baili.index);
    });

    test('Hive 写入并重读后状态仍存在', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      cult.attemptTribulation(
          realmLevel: 6, stageIndex: 0, now: _t0, random: _FixedRandom(0.0));
      // 重新打开（模拟重启后读取）
      final second = CultivationNotifier(cultivationBox, statsBox);
      final recs = second.state.profile.tribulations;
      expect(recs.length, 1);
      expect(recs.first.realmLevel, 6);
      expect(recs.first.stageIndex, 1);
      expect(recs.first.lastAttemptAt, _t0);
    });

    test('旧 TribulationRecord field 3 缺失兼容（lastAttemptAt = null）', () async {
      final profile = PlayerProfile();
      profile.tribulations
          .add(TribulationRecord(realmLevel: 6, stageIndex: 0, failCount: 2));
      await cultivationBox.add(profile);
      final stored = cultivationBox.values.first;
      expect(stored.tribulations.single.lastAttemptAt, isNull);
      expect(stored.tribulations.single.failCount, 2);
    });

    test('重复 key 安全处理：取第一条有效记录', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _seedRecord(cult, 6, 0, failCount: 1);
      _seedRecord(cult, 6, 0, failCount: 5);
      final r = cult.attemptTribulation(
          realmLevel: 6, stageIndex: 0, now: _t0, random: _FixedRandom(1.0));
      expect(r.success, isFalse);
      final recs = cult.state.profile.tribulations;
      expect(recs.length, 2); // 不批量重构，保留原列表
      expect(recs.first.failCount, 2); // 第一条 1 → 2
      expect(recs.first.lastAttemptAt, _t0);
    });

    test('stage 3 无法再次渡劫（invalid，不写 Hive）', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _seedRecord(cult, 6, 3);
      final before = cult.state.profile.tribulations.length;
      final r = cult.attemptTribulation(
          realmLevel: 6, stageIndex: 3, now: _t0, random: _FixedRandom(0.0));
      expect(r.outcome, TribulationOutcome.invalid);
      expect(cult.state.profile.tribulations.length, before);
    });

    test('非法 realmLevel → invalid，不写 Hive', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final r = cult.attemptTribulation(
          realmLevel: 5, stageIndex: 0, now: _t0, random: _FixedRandom(0.0));
      expect(r.outcome, TribulationOutcome.invalid);
      expect(cult.state.profile.tribulations, isEmpty);
    });
  });
}
