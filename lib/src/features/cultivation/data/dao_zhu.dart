import 'package:hive/hive.dart';

part 'dao_zhu.g.dart';

/// 道主记录（预留）。
///
/// 未来道主必须满足：九转蛊尊、该流派达到无上大宗师、当世对该流派理解最深；
/// 同一时代同一流派只能存在一位道主。
/// 本阶段仅建立数据结构，不实现道主竞争机制。
@HiveType(typeId: 5)
class DaoZhuState {
  /// 流派（Faction.index）。
  @HiveField(0)
  final int faction;

  /// 成为道主的时间。
  @HiveField(1)
  final DateTime crownedAt;

  /// 时代标识（预留全局唯一约束）。
  @HiveField(2)
  final String eraId;

  DaoZhuState({
    required this.faction,
    required this.crownedAt,
    required this.eraId,
  });
}
