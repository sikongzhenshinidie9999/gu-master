import 'package:hive/hive.dart';

import 'dao_zhu.dart';
import 'gu_insect.dart';
import 'gu_material.dart';
import 'tribulation_record.dart';

part 'player_profile.g.dart';

/// 仙元状态（预留九转突破）。
enum XianYuanType {
  none('无'),
  baili('白荔仙元'),
  huangxing('黄杏仙元');

  const XianYuanType(this.label);

  /// 显示名。
  final String label;
}

/// 玩家档案（cultivation 域聚合根）。
///
/// - totalXp：累计修为，永不因渡劫失败而减少；
/// - currentCultivation：当前有效修为，未来渡劫失败只减少此值；
///   首次初始化时 currentCultivation = totalXp，兼容现有用户。
@HiveType(typeId: 1)
class PlayerProfile extends HiveObject {
  /// 累计修为（兼容现有 stats.totalXp 语义）。
  @HiveField(0)
  int totalXp;

  /// 当前有效修为（渡劫可能扣减）。
  @HiveField(1)
  int currentCultivation;

  /// 道痕：DaoKind.index -> 道痕数量。
  @HiveField(2)
  Map<int, int> daoTraces;

  /// 流派境界（废弃为业务数据源，仅用于 Hive 兼容；不读取、不写入、不参与境界计算）。
  @HiveField(3)
  Map<int, int> factionLevels;

  /// 渡劫记录（每个转数 × 小阶独立）。
  @HiveField(4)
  List<TribulationRecord> tribulations;

  /// 蛊材背包。
  @HiveField(5)
  List<GuMaterial> guMaterials;

  /// 蛊虫集合。
  @HiveField(6)
  List<GuInsect> guInsects;

  /// 仙元状态（XianYuanType.index，0=无）。
  @HiveField(7)
  int xianYuan;

  /// 道主记录（预留）。
  @HiveField(8)
  DaoZhuState? daoZhu;

  /// 流派大道感悟（唯一境界成长源）：Faction.index -> 感悟值。
  ///
  /// 与 daoTraces 完全独立：道痕是力量、感悟是境界经验，二者不可互相转换；
  /// FactionLevel 仅由本字段派生；道主除外（见 DaoZhuState）。
  @HiveField(9)
  Map<int, int> factionRealmExp;

  /// 主修流派（Faction.index；null = 未指定，由 6A resolvePrimaryFaction 派生）。
  ///
  /// 仅作为显式偏好，不作为「已九转」的判断依据；旧玩家缺失时回退派生。
  @HiveField(10)
  int? primaryFaction;

  /// 是否已真正突破九转（唯一事实来源）。
  ///
  /// 绝不能由 realm totalXp / FactionLevel / daoTraces / factionRealmExp /
  /// xianYuan 中的任何单一条件代替。
  @HiveField(11, defaultValue: false)
  bool nineTurnReached;

  /// 九转突破时间。
  @HiveField(12)
  DateTime? nineTurnBreakthroughAt;

  PlayerProfile({
    this.totalXp = 0,
    this.currentCultivation = 0,
    Map<int, int>? daoTraces,
    Map<int, int>? factionLevels,
    List<TribulationRecord>? tribulations,
    List<GuMaterial>? guMaterials,
    List<GuInsect>? guInsects,
    this.xianYuan = 0,
    Map<int, int>? factionRealmExp,
    this.daoZhu,
    this.primaryFaction,
    this.nineTurnReached = false,
    this.nineTurnBreakthroughAt,
  })  : daoTraces = daoTraces ?? {},
        factionLevels = factionLevels ?? {},
        factionRealmExp = factionRealmExp ?? {},
        tribulations = tribulations ?? [],
        guMaterials = guMaterials ?? [],
        guInsects = guInsects ?? [];
}
