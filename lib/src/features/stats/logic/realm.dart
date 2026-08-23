// 境界与修为 —— 纯计算逻辑。
//
// 境界阈值集中定义在本文件，UI 只消费 getRealmProgress 的结果，
// 不要在页面中散落阈值。

/// 单个境界定义。
class CultivationRealm {
  const CultivationRealm({
    required this.name,
    required this.level,
    required this.threshold,
  });

  /// 境界名称，如「凡人」「一转蛊师」。
  final String name;

  /// 境界等级（0 起，凡人=0，九转尊者=9）。
  final int level;

  /// 达到该境界所需修为。
  final int threshold;
}

/// 境界阈值表：凡人 → 九转尊者。
const List<CultivationRealm> kRealms = [
  CultivationRealm(name: '凡人', level: 0, threshold: 0),
  CultivationRealm(name: '一转蛊师', level: 1, threshold: 100),
  CultivationRealm(name: '二转蛊师', level: 2, threshold: 300),
  CultivationRealm(name: '三转蛊师', level: 3, threshold: 600),
  CultivationRealm(name: '四转蛊师', level: 4, threshold: 1000),
  CultivationRealm(name: '五转蛊师', level: 5, threshold: 1500),
  CultivationRealm(name: '六转蛊仙', level: 6, threshold: 2500),
  CultivationRealm(name: '七转蛊仙', level: 7, threshold: 4000),
  CultivationRealm(name: '八转蛊仙', level: 8, threshold: 6000),
  CultivationRealm(name: '九转尊者', level: 9, threshold: 10000),
];

/// 境界计算结果的纯数据对象。
class RealmProgress {
  const RealmProgress({
    required this.name,
    required this.level,
    required this.currentThreshold,
    required this.progress,
    this.nextName,
    this.nextThreshold,
  });

  /// 当前境界名称。
  final String name;

  /// 当前境界等级（0 起）。
  final int level;

  /// 当前境界所需修为。
  final int currentThreshold;

  /// 下一境界名称；最高境界（九转尊者）时为 null。
  final String? nextName;

  /// 下一境界所需修为；最高境界时为 null。
  final int? nextThreshold;

  /// 当前境界进度（0.0 ~ 1.0），最高境界时为 1.0。
  final double progress;

  /// 是否为最高境界（九转尊者）。
  bool get isMaxRealm => nextThreshold == null;
}

/// 根据总修为计算当前境界与进度（纯计算，不依赖任何状态）。
RealmProgress getRealmProgress(int totalXp) {
  var current = kRealms.first;
  for (final realm in kRealms) {
    if (totalXp >= realm.threshold) {
      current = realm;
    } else {
      break;
    }
  }

  final next = current.level < kRealms.length - 1
      ? kRealms[current.level + 1]
      : null;

  double progress;
  if (next == null) {
    progress = 1.0; // 最高境界视为满进度
  } else {
    final span = next.threshold - current.threshold;
    final gained = totalXp - current.threshold;
    progress = span <= 0 ? 1.0 : (gained / span).clamp(0.0, 1.0).toDouble();
  }

  return RealmProgress(
    name: current.name,
    level: current.level,
    currentThreshold: current.threshold,
    nextName: next?.name,
    nextThreshold: next?.threshold,
    progress: progress,
  );
}
