import 'package:hive/hive.dart';

part 'tribulation_record.g.dart';

/// 渡劫记录。
///
/// 每个「转数 × 小阶」的劫难拥有独立失败次数；
/// 失败次数越多，下次通过该劫难的成功率越高。
@HiveType(typeId: 2)
class TribulationRecord {
  /// 转数（未来六转=6、七转=7、八转=8）。
  @HiveField(0)
  final int realmLevel;

  /// 小阶索引：0=1/3，1=2/3，2=3/3，3=该转渡劫已完成（终点 sentinel，非第四次渡劫）。
  @HiveField(1)
  final int stageIndex;

  /// 该具体劫难的失败次数（独立记录，不与其他劫难合并）。
  @HiveField(2)
  int failCount;

  /// 最近一次尝试时间（冷却用；null = 从未尝试）。
  @HiveField(3)
  DateTime? lastAttemptAt;

  TribulationRecord({
    required this.realmLevel,
    required this.stageIndex,
    this.failCount = 0,
    this.lastAttemptAt,
  });
}
