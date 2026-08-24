// 流派境界 —— 纯派生逻辑（由该流派境界感悟值派生；不写 Hive、不修改 Provider）。

import '../data/dao.dart';
import '../data/faction_level.dart';
import 'faction_realm_config.dart';

/// 流派境界进度（纯数据）。
class FactionRealmProgress {
  const FactionRealmProgress({
    required this.faction,
    required this.level,
    required this.levelIndex,
    required this.currentThreshold,
    required this.progress,
    this.nextThreshold,
  });

  /// 流派。
  final Faction faction;

  /// 当前境界（普通 .. 无上大宗师；道主不由感悟值派生）。
  final FactionLevel level;

  /// 境界索引（0=普通 .. 4=无上大宗师）。
  final int levelIndex;

  /// 当前境界所需感悟值。
  final int currentThreshold;

  /// 下一境界所需感悟值；无上大宗师时 null（封顶）。
  final int? nextThreshold;

  /// 当前境界进度（0.0~1.0），无上大宗师时为 1.0。
  final double progress;

  /// 是否已到可攀登的最高境界（无上大宗师）。
  bool get isCapped => nextThreshold == null;
}

/// 根据该流派境界感悟值派生境界进度（纯函数）。
///
/// - 感悟值（factionRealmExp）为唯一境界成长数据源，与 daoTraces 完全独立；
/// - 超过无上大宗师阈值后保持无上大宗师（isCapped=true），感悟仍继续累计；
/// - 道主（FactionLevel.daoLord）不由感悟值自动产生（见 DaoZhuState）。
FactionRealmProgress getFactionRealmProgress(
    Faction faction, int realmExp) {
  var levelIndex = 0;
  for (var i = 0; i < kFactionRealmExpThresholds.length; i++) {
    if (realmExp >= kFactionRealmExpThresholds[i]) {
      levelIndex = i;
    } else {
      break;
    }
  }

  final isCapped = levelIndex >= kFactionRealmExpThresholds.length - 1;
  final nextThreshold =
      isCapped ? null : kFactionRealmExpThresholds[levelIndex + 1];

  double progress;
  if (nextThreshold == null) {
    progress = 1.0;
  } else {
    final span = nextThreshold - kFactionRealmExpThresholds[levelIndex];
    final gained = realmExp - kFactionRealmExpThresholds[levelIndex];
    progress = span <= 0 ? 1.0 : (gained / span).clamp(0.0, 1.0).toDouble();
  }

  return FactionRealmProgress(
    faction: faction,
    level: FactionLevel.values[levelIndex],
    levelIndex: levelIndex,
    currentThreshold: kFactionRealmExpThresholds[levelIndex],
    nextThreshold: nextThreshold,
    progress: progress,
  );
}
