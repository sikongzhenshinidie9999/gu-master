// 渡劫（纯逻辑，不依赖 Hive / Provider，不修改任何状态）。
//
// - 成功率：base + failCompensation × failCount，clamp 到 min/max；
// - 惩罚：realmSpan × 1/3（round，至少 1），只返回数值，不写状态；
// - 冷却：成功与失败均进入冷却；now < lastAttemptAt 视为冷却中；
// - stageIndex == 3 为「完成」sentinel，不允许再次尝试。

import 'dart:math';

import 'tribulation_config.dart';

/// 渡劫类型。
enum TribulationType {
  normal,
  venerable,
  invalid,
}

/// 渡劫结果状态。
enum TribulationOutcome {
  success,
  failure,
  onCooldown,
  invalid,
}

/// 渡劫结果（纯数据）。
class TribulationResult {
  const TribulationResult({
    required this.success,
    required this.outcome,
    required this.tribulationType,
    required this.realmLevel,
    required this.stageIndex,
    required this.nextStageIndex,
    required this.failCount,
    required this.cultivationPenalty,
    required this.successRate,
  });

  /// 是否成功。
  final bool success;

  /// 结果状态。
  final TribulationOutcome outcome;

  /// 渡劫类型。
  final TribulationType tribulationType;

  /// 目标转数。
  final int realmLevel;

  /// 本次尝试的小阶索引。
  final int stageIndex;

  /// 尝试后的目标小阶（成功时推进；失败/冷却/非法时等于 stageIndex）。
  final int nextStageIndex;

  /// 尝试后的失败次数（失败时 = 原值+1；成功时 = 0）。
  final int failCount;

  /// 失败时应扣减的修为（成功/冷却/非法时为 0）。
  final int cultivationPenalty;

  /// 本次成功率。
  final double successRate;
}

/// 渡劫类型：6/7/8 = normal，9 = venerable，其余 invalid。
TribulationType getTribulationType(int realmLevel) {
  if (!kTribulationRealmLevels.contains(realmLevel)) {
    return TribulationType.invalid;
  }
  return realmLevel == 9 ? TribulationType.venerable : TribulationType.normal;
}

/// 成功率 = base + failCompensation × failCount，clamp 到 min/max。
///
/// failCount 极端大值不会产生 Infinity / NaN（乘法有界，再 clamp）。
double calculateTribulationSuccessRate({
  required int realmLevel,
  required int failCount,
}) {
  final base = kTribulationBaseSuccessRateByRealm[realmLevel] ?? 0.0;
  final safeFailCount = failCount < 0 ? 0 : failCount;
  final rate = base + kTribulationFailCompensationPerFail * safeFailCount;
  return rate.clamp(kTribulationMinSuccessRate, kTribulationMaxSuccessRate)
      .toDouble();
}

/// 失败惩罚：realmSpan × 1/3（round），至少 1。
int calculateCultivationPenalty({required int realmSpan}) {
  if (realmSpan <= 0) return 1; // 安全兜底
  final raw = realmSpan * kTribulationPenaltyNumerator /
      kTribulationPenaltyDenominator;
  final rounded = raw.round();
  return rounded < 1 ? 1 : rounded;
}

/// 是否处于冷却中。
///
/// - lastAttemptAt == null → false；
/// - now < lastAttemptAt（时间倒退）→ true；
/// - now - lastAttemptAt < cooldown → true；
/// - now - lastAttemptAt >= cooldown（含恰好等于）→ false。
bool isTribulationOnCooldown({
  DateTime? lastAttemptAt,
  required DateTime now,
}) {
  if (lastAttemptAt == null) return false;
  if (now.isBefore(lastAttemptAt)) return true;
  return now.difference(lastAttemptAt) < kTribulationCooldown;
}

/// 尝试渡劫（纯函数，不修改任何状态）。
///
/// - 非法 realmLevel / 非法 stageIndex（含 3 = 完成 sentinel）→ invalid；
/// - 尊者劫（realmLevel 9）只允许 stageIndex 0，其余 invalid；
/// - 冷却中 → onCooldown；
/// - 成功：普通劫 0→1→2→3、尊者劫 0→3，failCount 重置 0；
/// - 失败：nextStageIndex 不变、failCount = 原值+1、penalty = span/3。
TribulationResult attemptTribulation({
  required int realmLevel,
  required int stageIndex,
  required int failCount,
  required DateTime now,
  required int realmSpan,
  DateTime? lastAttemptAt,
  Random? random,
}) {
  final type = getTribulationType(realmLevel);
  if (type == TribulationType.invalid) {
    return _invalid(realmLevel, stageIndex);
  }
  if (stageIndex < 0 || stageIndex >= kTribulationStagesPerRealm) {
    return _invalid(realmLevel, stageIndex);
  }
  if (type == TribulationType.venerable && stageIndex != 0) {
    return _invalid(realmLevel, stageIndex);
  }
  if (isTribulationOnCooldown(lastAttemptAt: lastAttemptAt, now: now)) {
    return TribulationResult(
      success: false,
      outcome: TribulationOutcome.onCooldown,
      tribulationType: type,
      realmLevel: realmLevel,
      stageIndex: stageIndex,
      nextStageIndex: stageIndex,
      failCount: failCount,
      cultivationPenalty: 0,
      successRate:
          calculateTribulationSuccessRate(realmLevel: realmLevel, failCount: failCount),
    );
  }

  final successRate =
      calculateTribulationSuccessRate(realmLevel: realmLevel, failCount: failCount);
  final rng = random ?? Random();
  final success = rng.nextDouble() < successRate;

  if (!success) {
    return TribulationResult(
      success: false,
      outcome: TribulationOutcome.failure,
      tribulationType: type,
      realmLevel: realmLevel,
      stageIndex: stageIndex,
      nextStageIndex: stageIndex,
      failCount: failCount + 1,
      cultivationPenalty: calculateCultivationPenalty(realmSpan: realmSpan),
      successRate: successRate,
    );
  }

  final next = type == TribulationType.venerable
      ? kTribulationCompletedStageIndex
      : stageIndex + 1;
  return TribulationResult(
    success: true,
    outcome: TribulationOutcome.success,
    tribulationType: type,
    realmLevel: realmLevel,
    stageIndex: stageIndex,
    nextStageIndex: next,
    failCount: 0,
    cultivationPenalty: 0,
    successRate: successRate,
  );
}

TribulationResult _invalid(int realmLevel, int stageIndex) {
  return TribulationResult(
    success: false,
    outcome: TribulationOutcome.invalid,
    tribulationType: getTribulationType(realmLevel),
    realmLevel: realmLevel,
    stageIndex: stageIndex,
    nextStageIndex: stageIndex,
    failCount: 0,
    cultivationPenalty: 0,
    successRate: 0.0,
  );
}
