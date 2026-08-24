// 渡劫触发 —— 纯逻辑（修为里程碑自动来临）。
//
// 规则（成仙之后，六/七/八/九转）：
// - 当前修为（currentCultivation）达到该转数 1/3、2/3、3/3 里程碑时，对应劫难自动到期；
// - 渡劫失败会扣当前修为（跌回里程碑以下），修为再次达到时再次到期（直到渡过）；
// - 累计修为（totalXp）永不减少，只用于派生当前转数。

import '../../stats/logic/realm.dart';
import '../data/tribulation_record.dart';
import 'tribulation_config.dart';

/// 该转数某小阶（stage 0/1/2）的触发里程碑（绝对修为值）。
///
/// milestone = 该转起点 + 跨度 × (stageIndex + 1) / 3
int tribulationMilestone(int realmLevel, int stageIndex) {
  if (realmLevel < 0 || realmLevel >= kRealms.length) return 0;
  final threshold = kRealms[realmLevel].threshold;
  final span = tribulationRealmSpan(realmLevel);
  if (span <= 0) return threshold;
  return threshold +
      ((span * (stageIndex + 1)) ~/ kTribulationStagesPerRealm);
}

/// 该转数已渡过的劫难数（0~3；取该转数 stageIndex 最高记录）。
int passedTribulationCountForRealm(
    int realmLevel, List<TribulationRecord> tribulations) {
  var passed = 0;
  for (final r in tribulations) {
    if (r.realmLevel == realmLevel && r.stageIndex > passed) {
      passed = r.stageIndex;
    }
  }
  return passed;
}

/// 已度过劫难总次数（六/七/八/九转合计）。
int totalPassedTribulations(List<TribulationRecord> tribulations) {
  var total = 0;
  for (final realm in kTribulationRealmLevels) {
    total += passedTribulationCountForRealm(realm, tribulations);
  }
  return total;
}

/// 该转数当前「已到期且未渡过」的 stage（0/1/2）；无则返回 null。
///
/// - 已渡过（record stageIndex > stage）的 stage 跳过；
/// - 当前修为达到该 stage 里程碑且未渡过 → 到期；
/// - 该转已完成（渡过 3 次）→ null。
int? dueTribulationStage({
  required int realmLevel,
  required int currentCultivation,
  required List<TribulationRecord> tribulations,
}) {
  // 渡劫只在成仙（六转）之后；凡人~五转无劫难
  if (!kTribulationRealmLevels.contains(realmLevel)) return null;
  final passed = passedTribulationCountForRealm(realmLevel, tribulations);
  if (passed >= kTribulationStagesPerRealm) return null;
  for (var s = passed; s < kTribulationStagesPerRealm; s++) {
    if (currentCultivation >= tribulationMilestone(realmLevel, s)) {
      return s;
    }
  }
  return null;
}

/// 距下一劫难的修为差（扫描 6/7/8/9 转所有未渡过小阶中，最近一个大于当前修为的里程碑）。
///
/// 已全部渡过或无下一劫难时返回 0。
int distanceToNextTribulation({
  required int currentCultivation,
  required List<TribulationRecord> tribulations,
}) {
  int? next;
  for (final realm in kTribulationRealmLevels) {
    final passed = passedTribulationCountForRealm(realm, tribulations);
    for (var s = passed; s < kTribulationStagesPerRealm; s++) {
      final m = tribulationMilestone(realm, s);
      if (m > currentCultivation && (next == null || m < next)) {
        next = m;
      }
    }
  }
  return next == null ? 0 : next - currentCultivation;
}
