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

  /// 小阶索引：0=1/3，1=2/3，2=3/3。
  @HiveField(1)
  final int stageIndex;

  /// 该具体劫难的失败次数（独立记录，不与其他劫难合并）。
  @HiveField(2)
  int failCount;

  TribulationRecord({
    required this.realmLevel,
    required this.stageIndex,
    this.failCount = 0,
  });
}
