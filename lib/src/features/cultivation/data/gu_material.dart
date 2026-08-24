import 'package:hive/hive.dart';

part 'gu_material.g.dart';

/// 蛊材类型（可扩展）。
enum GuMaterialType {
  bronzeSand('青铜沙'),
  ironPowder('玄铁粉'),
  bloodLotus('血莲瓣');

  const GuMaterialType(this.label);

  /// 显示名。
  final String label;
}

/// 蛊材（一种类型 + 数量）。
///
/// 蛊材通过完成任务概率获得、用于炼蛊（后续阶段实现）。
@HiveType(typeId: 4)
class GuMaterial {
  /// 蛊材类型（GuMaterialType.index）。
  @HiveField(0)
  final int type;

  /// 数量。
  @HiveField(1)
  int quantity;

  GuMaterial({required this.type, this.quantity = 0});
}
