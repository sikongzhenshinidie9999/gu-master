import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:sidequest/src/features/cultivation/data/dao.dart';
import 'package:sidequest/src/features/cultivation/logic/session_reward_calculator.dart';
import 'package:sidequest/src/features/cultivation/logic/session_reward_config.dart';

void main() {
  group('computeSessionReward', () {
    test('25 分钟学习获得奖励（英语 → 炼神/智道）', () {
      final r = computeSessionReward(subject: '英语', actualMinutes: 25);
      expect(r.xp, 25 * kSessionXpPerMinute);
      expect(r.daoKind, DaoKind.zhi);
      expect(r.daoTraceAmount, 25 * kSessionDaoTracePerMinute);
      expect(r.realmExp, 25 * kSessionRealmExpPerMinute);
    });

    test('90 分钟奖励高于 25 分钟', () {
      final short = computeSessionReward(subject: '英语', actualMinutes: 25);
      final long = computeSessionReward(subject: '英语', actualMinutes: 90);
      expect(long.xp, greaterThan(short.xp));
      expect(long.daoTraceAmount, greaterThan(short.daoTraceAmount));
      expect(long.realmExp, greaterThan(short.realmExp));
    });

    test('0 分钟无奖励', () {
      final r = computeSessionReward(subject: '英语', actualMinutes: 0);
      expect(r.xp, 0);
      expect(r.daoKind, isNull);
      expect(r.daoTraceAmount, 0);
      expect(r.realmExp, 0);
    });

    test('负数安全（按 0 处理，不产生负数奖励）', () {
      final r = computeSessionReward(subject: '英语', actualMinutes: -30);
      expect(r.xp, 0);
      expect(r.daoTraceAmount, 0);
      expect(r.realmExp, 0);
      expect(r.xp.isNegative, isFalse);
      expect(r.daoTraceAmount.isNegative, isFalse);
    });

    test('学科映射正确：数学/408/专业课 → 悟道（随机流派、倍率更高）', () {
      for (final subject in ['数学', '408', '专业课']) {
        final r = computeSessionReward(
            subject: subject, actualMinutes: 30, random: Random(1));
        expect(r.daoKind, anyOf(DaoKind.li, DaoKind.zhi, DaoKind.lian),
            reason: '$subject 应解析为悟道随机流派');
        expect(
          r.daoTraceAmount,
          (30 * kSessionDaoTracePerMinute * kSessionWudaoMultiplier).round(),
        );
      }
    });

    test('学科映射正确：英语 → 炼神（智道），其他 → 杂务（仅修为）', () {
      final en = computeSessionReward(subject: '英语', actualMinutes: 25);
      expect(en.daoKind, DaoKind.zhi);

      final other = computeSessionReward(subject: '物理', actualMinutes: 25);
      expect(other.daoKind, isNull);
      expect(other.daoTraceAmount, 0);
      expect(other.realmExp, 0);
      expect(other.xp, 25 * kSessionXpPerMinute);
    });

    test('极端时长不会溢出（封顶 kSessionMaxMinutes）', () {
      final r = computeSessionReward(subject: '英语', actualMinutes: 1 << 30);
      expect(r.xp, kSessionMaxMinutes * kSessionXpPerMinute);
      expect(r.daoTraceAmount, kSessionMaxMinutes * kSessionDaoTracePerMinute);
      expect(r.realmExp, kSessionMaxMinutes * kSessionRealmExpPerMinute);
      expect(r.xp.isFinite, isTrue);
      expect(r.daoTraceAmount.isFinite, isTrue);
    });

    test('纯函数：不修改输入，重复调用结果一致', () {
      const subject = '英语';
      final r1 = computeSessionReward(subject: subject, actualMinutes: 45);
      final r2 = computeSessionReward(subject: subject, actualMinutes: 45);
      expect(r1.xp, r2.xp);
      expect(r1.daoKind, r2.daoKind);
      expect(r1.daoTraceAmount, r2.daoTraceAmount);
      expect(r1.realmExp, r2.realmExp);
      expect(subject, '英语'); // 输入未被修改
    });

    test('预设时长包含 25/45/90', () {
      expect(kSessionPresetMinutes, [25, 45, 90]);
    });
  });
}
