// 道痕与流派定义（可扩展枚举 + 配置）。
//
// 未来新增道痕/流派时，只需扩展这里的枚举，无需修改业务逻辑。

/// 道痕类型。
enum DaoKind {
  none('无'),
  li('力道'),
  zhi('智道'),
  lian('炼道');

  const DaoKind(this.label);

  /// 显示名。
  final String label;
}

/// 流派。
///
/// 每个流派对应一种道痕；未来若出现不对应道痕的流派，可调整此映射。
enum Faction {
  li('力道流派', DaoKind.li),
  zhi('智道流派', DaoKind.zhi),
  lian('炼道流派', DaoKind.lian);

  const Faction(this.label, this.daoKind);

  /// 显示名。
  final String label;

  /// 关联道痕类型。
  final DaoKind daoKind;
}
