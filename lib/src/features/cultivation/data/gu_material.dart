import 'package:hive/hive.dart';

part 'gu_material.g.dart';

/// 蛊材（一种材料 + 数量）。
///
/// 蛊材通过完成任务概率获得、用于炼蛊。
/// materialId 对应 GuMaterialDefinition.materialId（见 gu_material_definition.dart）。
@HiveType(typeId: 4)
class GuMaterial {
  /// 蛊材标识（稳定字符串，不受枚举顺序影响）。
  @HiveField(0)
  final String materialId;

  /// 数量。
  @HiveField(1)
  int quantity;

  GuMaterial({required this.materialId, this.quantity = 0});
}
