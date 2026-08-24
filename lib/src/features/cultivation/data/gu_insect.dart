import 'package:hive/hive.dart';

part 'gu_insect.g.dart';

/// 蛊虫。
///
/// 蛊虫只能通过炼蛊获得（后续阶段实现），本阶段仅建立数据模型。
@HiveType(typeId: 3)
class GuInsect {
  /// 唯一标识。
  @HiveField(0)
  final String id;

  /// 蛊虫转数。
  @HiveField(1)
  final int turn;

  /// 炼制成功时玩家的炼道境界（FactionLevel.index 快照）。
  @HiveField(2)
  final int refinedDaoLevel;

  GuInsect({
    required this.id,
    required this.turn,
    required this.refinedDaoLevel,
  });
}
