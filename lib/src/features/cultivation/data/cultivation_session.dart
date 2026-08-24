import 'package:hive/hive.dart';

part 'cultivation_session.g.dart';

/// 闭关状态。
enum CultivationSessionStatus {
  running,
  paused,
  completed,
  cancelled,
}

/// 闭关修炼分类（学科映射目标，非 DaoKind）。
enum CultivationSessionCategory {
  ti('炼体'),
  shen('炼神'),
  gu('炼蛊'),
  wudao('悟道'),
  misc('杂务');

  const CultivationSessionCategory(this.label);

  /// 显示名。
  final String label;
}

/// 闭关记录（番茄钟学习打卡）。
///
/// 只负责存储，不包含业务逻辑。
@HiveType(typeId: 6)
class CultivationSession {
  /// 唯一标识。
  @HiveField(0)
  final String id;

  /// 开始时间。
  @HiveField(1)
  final DateTime startTime;

  /// 结束时间（进行中为 null）。
  @HiveField(2)
  final DateTime? endTime;

  /// 预设时长（分钟）。
  @HiveField(3)
  final int plannedDurationMinutes;

  /// 实际专注时长（分钟）。
  @HiveField(4)
  final int actualDurationMinutes;

  /// 学科。
  @HiveField(5)
  final String subject;

  /// 修炼分类（CultivationSessionCategory.index）。
  @HiveField(6)
  final int category;

  /// 状态（CultivationSessionStatus.index）。
  @HiveField(7)
  final int status;

  /// 本次获得修为。
  @HiveField(8)
  final int xpEarned;

  /// 实际道痕流派（DaoKind.index；杂务为 null）。
  @HiveField(9)
  final int? daoTraceKind;

  /// 本次道痕数量。
  @HiveField(10)
  final int daoTraceAmount;

  /// 本次流派感悟。
  @HiveField(11)
  final int realmExpEarned;

  CultivationSession({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.plannedDurationMinutes,
    required this.actualDurationMinutes,
    required this.subject,
    required this.category,
    required this.status,
    this.xpEarned = 0,
    this.daoTraceKind,
    this.daoTraceAmount = 0,
    this.realmExpEarned = 0,
  });

  /// 复制并覆盖部分字段（纯数据便利方法；状态推进由 Provider 使用）。
  CultivationSession copyWith({
    DateTime? endTime,
    int? actualDurationMinutes,
    int? status,
    int? xpEarned,
    int? daoTraceKind,
    int? daoTraceAmount,
    int? realmExpEarned,
  }) {
    return CultivationSession(
      id: id,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      plannedDurationMinutes: plannedDurationMinutes,
      actualDurationMinutes: actualDurationMinutes ?? this.actualDurationMinutes,
      subject: subject,
      category: category,
      status: status ?? this.status,
      xpEarned: xpEarned ?? this.xpEarned,
      daoTraceKind: daoTraceKind ?? this.daoTraceKind,
      daoTraceAmount: daoTraceAmount ?? this.daoTraceAmount,
      realmExpEarned: realmExpEarned ?? this.realmExpEarned,
    );
  }
}
