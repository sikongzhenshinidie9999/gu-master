import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:sidequest/src/features/cultivation/logic/tribulation_config.dart';
import 'package:sidequest/src/features/cultivation/logic/tribulation_service.dart';

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

final DateTime _now = DateTime(2026, 8, 24, 12, 0);

void main() {
  group('calculateTribulationSuccessRate', () {
    test('6/7/8/9 基础成功率', () {
      expect(calculateTribulationSuccessRate(realmLevel: 6, failCount: 0),
          closeTo(0.90, 1e-9));
      expect(calculateTribulationSuccessRate(realmLevel: 7, failCount: 0),
          closeTo(0.80, 1e-9));
      expect(calculateTribulationSuccessRate(realmLevel: 8, failCount: 0),
          closeTo(0.70, 1e-9));
      expect(calculateTribulationSuccessRate(realmLevel: 9, failCount: 0),
          closeTo(0.50, 1e-9));
    });

    test('failCount 成功率补偿（每次 +0.10）', () {
      expect(calculateTribulationSuccessRate(realmLevel: 9, failCount: 1),
          closeTo(0.60, 1e-9));
      expect(calculateTribulationSuccessRate(realmLevel: 8, failCount: 1),
          closeTo(0.80, 1e-9));
    });

    test('min/max clamp', () {
      // 极端 failCount → 封顶 max
      expect(calculateTribulationSuccessRate(realmLevel: 9, failCount: 999),
          closeTo(kTribulationMaxSuccessRate, 1e-9));
      // 无配置转数（base 0）→ 下限 min
      expect(calculateTribulationSuccessRate(realmLevel: 5, failCount: 0),
          closeTo(kTribulationMinSuccessRate, 1e-9));
    });
  });

  group('calculateCultivationPenalty', () {
    test('realmSpan × 1/3（round），至少 1', () {
      expect(calculateCultivationPenalty(realmSpan: 1000), 333);
      expect(calculateCultivationPenalty(realmSpan: 1500), 500);
      expect(calculateCultivationPenalty(realmSpan: 2000), 667);
      expect(calculateCultivationPenalty(realmSpan: 4000), 1333);
      expect(calculateCultivationPenalty(realmSpan: 1), 1);
      expect(calculateCultivationPenalty(realmSpan: 0), 1);
    });
  });

  group('isTribulationOnCooldown', () {
    test('lastAttemptAt == null → false', () {
      expect(isTribulationOnCooldown(lastAttemptAt: null, now: _now), isFalse);
    });

    test('冷却中（未满 24h）→ true', () {
      expect(
        isTribulationOnCooldown(
            lastAttemptAt: _now.subtract(const Duration(hours: 1)), now: _now),
        isTrue,
      );
    });

    test('冷却边界（恰好 24h）→ false', () {
      expect(
        isTribulationOnCooldown(
            lastAttemptAt: _now.subtract(kTribulationCooldown), now: _now),
        isFalse,
      );
    });

    test('时间倒退（now < lastAttemptAt）→ true', () {
      expect(
        isTribulationOnCooldown(
            lastAttemptAt: _now.add(const Duration(hours: 1)), now: _now),
        isTrue,
      );
    });

    test('极端 DateTime（远超冷却）→ false，不崩溃', () {
      expect(
        isTribulationOnCooldown(
            lastAttemptAt: DateTime(2000, 1, 1), now: DateTime(3000, 1, 1)),
        isFalse,
      );
    });
  });

  group('attemptTribulation', () {
    test('普通劫 stage 0 成功 → nextStageIndex 1', () {
      final r = attemptTribulation(
        realmLevel: 6,
        stageIndex: 0,
        failCount: 0,
        now: _now,
        realmSpan: 1000,
        random: _FixedRandom(0.0),
      );
      expect(r.success, isTrue);
      expect(r.outcome, TribulationOutcome.success);
      expect(r.tribulationType, TribulationType.normal);
      expect(r.nextStageIndex, 1);
      expect(r.failCount, 0);
      expect(r.cultivationPenalty, 0);
    });

    test('stage 1 成功 → 2', () {
      final r = attemptTribulation(
        realmLevel: 6,
        stageIndex: 1,
        failCount: 0,
        now: _now,
        realmSpan: 1000,
        random: _FixedRandom(0.0),
      );
      expect(r.success, isTrue);
      expect(r.nextStageIndex, 2);
    });

    test('stage 2 成功 → 3（完成 sentinel）', () {
      final r = attemptTribulation(
        realmLevel: 6,
        stageIndex: 2,
        failCount: 0,
        now: _now,
        realmSpan: 1000,
        random: _FixedRandom(0.0),
      );
      expect(r.success, isTrue);
      expect(r.nextStageIndex, kTribulationCompletedStageIndex);
    });

    test('stage 3（已完成）→ invalid，不允许再次尝试', () {
      final r = attemptTribulation(
        realmLevel: 6,
        stageIndex: 3,
        failCount: 0,
        now: _now,
        realmSpan: 1000,
        random: _FixedRandom(0.0),
      );
      expect(r.success, isFalse);
      expect(r.outcome, TribulationOutcome.invalid);
    });

    test('尊者劫 9 转 stage 0 成功 → 3', () {
      final r = attemptTribulation(
        realmLevel: 9,
        stageIndex: 0,
        failCount: 0,
        now: _now,
        realmSpan: 4000,
        random: _FixedRandom(0.0),
      );
      expect(r.success, isTrue);
      expect(r.tribulationType, TribulationType.venerable);
      expect(r.nextStageIndex, kTribulationCompletedStageIndex);
    });

    test('尊者劫 9 转 stage 1 非法 → invalid', () {
      final r = attemptTribulation(
        realmLevel: 9,
        stageIndex: 1,
        failCount: 0,
        now: _now,
        realmSpan: 4000,
        random: _FixedRandom(0.0),
      );
      expect(r.outcome, TribulationOutcome.invalid);
    });

    test('失败：nextStageIndex 不变、failCount+1、penalty>0', () {
      final r = attemptTribulation(
        realmLevel: 6,
        stageIndex: 1,
        failCount: 2,
        now: _now,
        realmSpan: 1000,
        random: _FixedRandom(1.0),
      );
      expect(r.success, isFalse);
      expect(r.outcome, TribulationOutcome.failure);
      expect(r.nextStageIndex, 1);
      expect(r.failCount, 3);
      expect(r.cultivationPenalty, greaterThan(0));
    });

    test('冷却中 → onCooldown，penalty 0', () {
      final r = attemptTribulation(
        realmLevel: 6,
        stageIndex: 0,
        failCount: 0,
        now: _now,
        realmSpan: 1000,
        lastAttemptAt: _now.subtract(const Duration(hours: 1)),
        random: _FixedRandom(0.0),
      );
      expect(r.outcome, TribulationOutcome.onCooldown);
      expect(r.success, isFalse);
      expect(r.cultivationPenalty, 0);
    });

    test('非法 realm → invalid', () {
      final r = attemptTribulation(
        realmLevel: 5,
        stageIndex: 0,
        failCount: 0,
        now: _now,
        realmSpan: 500,
        random: _FixedRandom(0.0),
      );
      expect(r.outcome, TribulationOutcome.invalid);
      expect(r.tribulationType, TribulationType.invalid);
    });

    test('非法 stage（负数）→ invalid', () {
      final r = attemptTribulation(
        realmLevel: 6,
        stageIndex: -1,
        failCount: 0,
        now: _now,
        realmSpan: 1000,
        random: _FixedRandom(0.0),
      );
      expect(r.outcome, TribulationOutcome.invalid);
    });

    test('极端 failCount 不产生 NaN / Infinity', () {
      final r = attemptTribulation(
        realmLevel: 8,
        stageIndex: 0,
        failCount: 100000,
        now: _now,
        realmSpan: 2000,
        random: _FixedRandom(1.0),
      );
      expect(r.successRate.isFinite, isTrue);
      expect(r.successRate.isNaN, isFalse);
      expect(r.failCount, 100001);
    });
  });
}
