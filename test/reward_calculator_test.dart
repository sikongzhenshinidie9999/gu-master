import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:sidequest/src/features/cultivation/data/dao.dart';
import 'package:sidequest/src/features/cultivation/logic/reward_calculator.dart';
import 'package:sidequest/src/features/quests/data/quest_model.dart';

QuestModel _quest(String category) => QuestModel(
  id: 'q_$category',
  title: '测试',
  description: '描述',
  tier: 1,
  createdAt: DateTime(2026, 1, 1),
  category: category,
);

void main() {
  group('computeCultivationReward', () {
    test('炼体任务 → 力道道痕增加', () {
      final r = computeCultivationReward(_quest('炼体'));
      expect(r.daoKind, DaoKind.li);
      expect(r.daoTraceAmount, greaterThan(0));
      expect(r.hasDaoTrace, isTrue);
    });

    test('炼神任务 → 智道道痕增加', () {
      final r = computeCultivationReward(_quest('炼神'));
      expect(r.daoKind, DaoKind.zhi);
      expect(r.daoTraceAmount, greaterThan(0));
    });

    test('炼蛊任务 → 炼道道痕增加', () {
      final r = computeCultivationReward(_quest('炼蛊'));
      expect(r.daoKind, DaoKind.lian);
      expect(r.daoTraceAmount, greaterThan(0));
    });

    test('杂务 → 不增加流派道痕', () {
      final r = computeCultivationReward(_quest('杂务'));
      expect(r.daoKind, isNull);
      expect(r.daoTraceAmount, 0);
      expect(r.hasDaoTrace, isFalse);
    });

    test('炼气 → 不增加流派道痕（系统任务兼容）', () {
      final r = computeCultivationReward(_quest('炼气'));
      expect(r.daoKind, isNull);
      expect(r.daoTraceAmount, 0);
    });

    test('悟道 → 固定 seed 下得到合法流派', () {
      for (var seed = 0; seed < 20; seed++) {
        final r = computeCultivationReward(_quest('悟道'), random: Random(seed));
        expect(r.daoKind, anyOf(DaoKind.li, DaoKind.zhi, DaoKind.lian));
        expect(r.daoTraceAmount, greaterThan(0));
      }
    });

    test('悟道 → 道痕奖励高于普通分类', () {
      final base = computeCultivationReward(_quest('炼体')).daoTraceAmount;
      final wudao =
          computeCultivationReward(_quest('悟道'), random: Random(1)).daoTraceAmount;
      expect(wudao, greaterThan(base));
    });
  });

  group('流派感悟奖励（与道痕独立）', () {
    test('炼体任务 → 同时获得道痕与流派感悟（同属力道）', () {
      final r = computeCultivationReward(_quest('炼体'));
      expect(r.daoKind, DaoKind.li);
      expect(r.daoTraceAmount, greaterThan(0));
      expect(r.realmExpGain, greaterThan(0));
      expect(r.hasRealmExp, isTrue);
    });

    test('炼神任务 → 获得智道道痕 + 智道感悟', () {
      final r = computeCultivationReward(_quest('炼神'));
      expect(r.daoKind, DaoKind.zhi);
      expect(r.realmExpGain, greaterThan(0));
    });

    test('炼蛊任务 → 获得炼道道痕 + 炼道感悟', () {
      final r = computeCultivationReward(_quest('炼蛊'));
      expect(r.daoKind, DaoKind.lian);
      expect(r.realmExpGain, greaterThan(0));
    });

    test('杂务 / 炼气 → 无道痕、无感悟', () {
      expect(computeCultivationReward(_quest('杂务')).realmExpGain, 0);
      expect(computeCultivationReward(_quest('杂务')).hasRealmExp, isFalse);
      expect(computeCultivationReward(_quest('炼气')).realmExpGain, 0);
    });

    test('悟道 → 道痕与感悟均高于普通分类', () {
      final baseDao = computeCultivationReward(_quest('炼体')).daoTraceAmount;
      final baseExp = computeCultivationReward(_quest('炼体')).realmExpGain;
      final wudao = computeCultivationReward(_quest('悟道'), random: Random(1));
      expect(wudao.daoTraceAmount, greaterThan(baseDao));
      expect(wudao.realmExpGain, greaterThan(baseExp));
    });

    test('悟道 → 道痕与感悟的随机流派保持一致', () {
      final r = computeCultivationReward(_quest('悟道'), random: Random(7));
      expect(r.daoKind, anyOf(DaoKind.li, DaoKind.zhi, DaoKind.lian));
      // 感悟与道痕同属该随机流派（同一 daoKind 承载两笔独立数值）
      expect(r.hasDaoTrace, isTrue);
      expect(r.hasRealmExp, isTrue);
    });
  });
}
