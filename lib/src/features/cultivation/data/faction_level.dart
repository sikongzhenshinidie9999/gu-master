/// 流派境界等级（可扩展）。
enum FactionLevel {
  ordinary('普通'),
  master('大师'),
  grandmaster('宗师'),
  greatGrandmaster('大宗师'),
  supremeGrandmaster('无上大宗师'),
  daoLord('道主');

  const FactionLevel(this.label);

  /// 显示名。
  final String label;
}
