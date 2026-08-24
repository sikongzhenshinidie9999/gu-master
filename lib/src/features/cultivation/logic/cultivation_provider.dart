import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sidequest/src/features/quests/data/quest_model.dart';
import 'package:sidequest/src/features/stats/logic/realm.dart';
import 'package:uuid/uuid.dart';

import '../data/dao.dart';
import '../data/dao_zhu.dart';
import '../data/gu_insect.dart';
import '../data/gu_material.dart';
import '../data/gu_recipe.dart';
import '../data/player_profile.dart';
import '../data/tribulation_record.dart';
import 'dao_zhu_service.dart';
import 'faction_realm.dart';
import 'gu_power_service.dart';
import 'nine_turn_prerequisites.dart';
import 'material_drop_service.dart';
import 'refining_config.dart';
import 'refining_service.dart' as refining;
import 'reward_calculator.dart';
import 'tribulation_config.dart';
import 'tribulation_service.dart' as tribulation;
import 'tribulation_trigger.dart';

/// 判断两个日期是否为同一天。
bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// cultivation Box Provider（由 main.dart 注入）。
final cultivationBoxProvider = Provider<Box<PlayerProfile>>((ref) {
  throw UnimplementedError('cultivationBoxProvider not initialized');
});

/// 修炼状态。
class CultivationState {
  final PlayerProfile profile;

  const CultivationState({required this.profile});
}

/// 九转突破结果状态。
enum NineTurnBreakthroughStatus {
  succeeded,
  alreadyReached,
  failed,
}

/// 九转突破结果（纯数据）。
class NineTurnBreakthroughResult {
  const NineTurnBreakthroughResult({
    required this.status,
    this.failureReason,
    this.nineTurnBreakthroughAt,
    this.xianYuanAfter,
  });

  /// 结果状态。
  final NineTurnBreakthroughStatus status;

  /// 失败/已突破原因（成功时为 null）。
  final String? failureReason;

  /// 突破时间（成功时非空）。
  final DateTime? nineTurnBreakthroughAt;

  /// 突破后的仙元（XianYuanType.index；失败时返回当前值）。
  final int? xianYuanAfter;

  /// 是否成功突破。
  bool get success => status == NineTurnBreakthroughStatus.succeeded;
}

/// 道主授予结果状态。
enum DaoZhuGrantStatus {
  succeeded,
  alreadyGranted,
  failed,
}

/// 道主授予结果（纯数据）。
class DaoZhuGrantResult {
  const DaoZhuGrantResult({
    required this.status,
    this.failureReason,
    this.daoZhu,
    this.crownedAt,
  });

  /// 结果状态。
  final DaoZhuGrantStatus status;

  /// 失败/已授予原因（成功时为 null）。
  final String? failureReason;

  /// 授予后的道主记录（成功时非空）。
  final DaoZhuState? daoZhu;

  /// 授予时间（成功时非空）。
  final DateTime? crownedAt;

  /// 是否成功授予。
  bool get success => status == DaoZhuGrantStatus.succeeded;
}

/// 修炼领域 Notifier。
///
/// 职责：读取 / 初始化 / 保存玩家档案，并提供任务奖励、炼蛊等动作。
class CultivationNotifier extends StateNotifier<CultivationState> {
  final Box<PlayerProfile> box;
  final Box<dynamic> statsBox;

  CultivationNotifier(this.box, this.statsBox)
      : super(CultivationState(profile: _loadOrCreate(box, statsBox)));

  /// 读取玩家档案；若不存在则用 stats.totalXp 初始化（兼容现有用户）。
  static PlayerProfile _loadOrCreate(
      Box<PlayerProfile> box, Box<dynamic> statsBox) {
    if (box.isNotEmpty) {
      return box.values.first;
    }
    final legacyXp = statsBox.get('totalXp', defaultValue: 0) as int;
    final profile = PlayerProfile(
      totalXp: legacyXp,
      currentCultivation: legacyXp,
    );
    box.add(profile);
    return profile;
  }

  /// 保存玩家档案到 Hive。
  void saveProfile(PlayerProfile profile) {
    profile.save();
    state = CultivationState(profile: profile);
  }

  /// 完成任务后的修炼奖励（由 QuestNotifier 回调触发，每次完成只执行一次）。
  ///
  /// 计算任务奖励后委托给共享入口 [applyCultivationGains]；
  /// 不影响 totalXp、streak、weeklyHistory 与任务完成主流程。
  void applyQuestCompletedRewards(
    QuestModel quest, {
    Random? random,
    int? materialDropTurn,
  }) {
    final reward = computeCultivationReward(quest);
    applyCultivationGains(
      daoKind: reward.daoKind,
      daoTraceAmount: reward.daoTraceAmount,
      realmExpGain: reward.realmExpGain,
      currentCultivationGain: quest.xpReward,
      applyMaterialDrop: true,
      random: random,
      materialDropTurn: materialDropTurn,
    );
  }

  /// 通用修炼奖励入口（任务与未来闭关共用）。
  ///
  /// - 道痕（力量）与流派感悟（境界成长）分别写入两个独立数据源，互不换算；
  /// - [daoKind] 为 null 时无流派奖励（道痕/感悟均不增加）；
  /// - 附加蛊材掉落（每日上限由 stats Box 记录，见 _applyMaterialDrop），
  ///   可用 [applyMaterialDrop] 关闭；
  /// - 仅在任一奖励生效时保存 profile；不影响 totalXp。
  ///
  /// [random] / [materialDropTurn] 为测试钩子：掉落随机可注入、掉落转数可覆盖。
  void applyCultivationGains({
    required DaoKind? daoKind,
    required int daoTraceAmount,
    required int realmExpGain,
    int currentCultivationGain = 0,
    bool applyMaterialDrop = true,
    Random? random,
    int? materialDropTurn,
  }) {
    final profile = state.profile;
    var changed = false;

    if (currentCultivationGain > 0) {
      // 当前修为随任务/闭关同步增长（累计修为 totalXp 由 statsBox 单独维护）
      profile.currentCultivation += currentCultivationGain;
      changed = true;
    }
    if (daoKind != null && daoTraceAmount > 0) {
      profile.daoTraces[daoKind.index] =
          (profile.daoTraces[daoKind.index] ?? 0) + daoTraceAmount;
      changed = true;
    }
    if (daoKind != null && realmExpGain > 0) {
      profile.factionRealmExp[daoKind.index] =
          (profile.factionRealmExp[daoKind.index] ?? 0) + realmExpGain;
      changed = true;
    }
    if (applyMaterialDrop &&
        _applyMaterialDrop(profile, random: random, turn: materialDropTurn)) {
      changed = true;
    }

    if (changed) {
      saveProfile(profile);
    }
  }

  /// 蛊材掉落（附加在任务完成奖励回调中）。
  ///
  /// - 每日上限：使用 stats Box 键 lastMaterialDropDay / dailyMaterialDropCount；
  /// - 日期变化重置计数；达到上限不再掉落；未掉落不增加计数；
  /// - 相同 materialId 堆叠，否则新增 GuMaterial(quantity: 1)。
  bool _applyMaterialDrop(
    PlayerProfile profile, {
    Random? random,
    int? turn,
  }) {
    final now = DateTime.now();
    final lastDay = statsBox.get('lastMaterialDropDay');
    var count = 0;
    if (lastDay is DateTime && _isSameDay(lastDay, now)) {
      count = statsBox.get('dailyMaterialDropCount', defaultValue: 0) as int;
    } else {
      // 新的一天：重置
      statsBox.put('lastMaterialDropDay', now);
      statsBox.put('dailyMaterialDropCount', 0);
    }

    if (count >= kMaxDailyMaterialDrops) {
      return false;
    }

    final materialId = rollMaterialDrop(
      currentTurn: turn ?? kDefaultMaterialDropTurn,
      random: random,
    );
    if (materialId == null) {
      return false;
    }

    final existing = profile.guMaterials
        .where((m) => m.materialId == materialId)
        .firstOrNull;
    if (existing != null) {
      existing.quantity += 1;
    } else {
      profile.guMaterials.add(GuMaterial(materialId: materialId, quantity: 1));
    }
    statsBox.put('dailyMaterialDropCount', count + 1);
    return true;
  }

  /// 炼蛊（由 UI 调用；Hive 持久化在 Provider，业务规则在 RefiningService）。
  ///
  /// 炼道境界只来自 factionRealmExp（感悟），绝不由 daoTraces（道痕）推导。
  refining.RefiningResult refineGuInsect({
    required String insectDefinitionId,
    Random? random,
  }) {
    final profile = state.profile;

    final lianRealmExp = profile.factionRealmExp[DaoKind.lian.index] ?? 0;
    final lianDaoLevel =
        getFactionRealmProgress(Faction.lian, lianRealmExp).level;

    final inventory = <String, int>{};
    for (final m in profile.guMaterials) {
      inventory[m.materialId] = (inventory[m.materialId] ?? 0) + m.quantity;
    }

    final result = refining.refineGuInsect(
      insectDefinitionId: insectDefinitionId,
      lianDaoLevel: lianDaoLevel,
      inventory: inventory,
      random: random,
    );

    _deductMaterials(profile, result.consumedMaterials);

    final gained = result.gainedInsect;
    if (result.success && gained != null) {
      profile.guInsects.add(GuInsect(
        id: const Uuid().v4(),
        turn: gained.turn,
        refinedDaoLevel: lianDaoLevel.index,
        definitionId: gained.definitionId,
        faction: gained.faction,
        quality: gained.quality,
      ));
    }

    saveProfile(profile);
    return result;
  }

  /// 按 RefiningResult 扣除蛊材（quantity <= consumed 移除，否则相减；禁止负数）。
  void _deductMaterials(
      PlayerProfile profile, List<GuRecipeMaterial> consumed) {
    if (consumed.isEmpty) return;
    for (final need in consumed) {
      for (var i = 0; i < profile.guMaterials.length; i++) {
        final m = profile.guMaterials[i];
        if (m.materialId == need.materialId) {
          if (m.quantity <= need.quantity) {
            profile.guMaterials.removeAt(i);
          } else {
            m.quantity -= need.quantity;
          }
          break;
        }
      }
    }
  }

  /// 单只蛊虫威能（只读派生，不写 Hive）。
  ///
  /// 威能只由 daoTraces（力量）与蛊虫自身属性派生，与 factionRealmExp 无关。
  GuInsectPowerResult insectPower(GuInsect insect) {
    return getGuInsectPower(
      insect: insect,
      daoTraces: state.profile.daoTraces,
    );
  }

  /// 指定流派总威能（只读派生，不写 Hive）。
  double factionPower(Faction faction) {
    return calculateFactionPower(
      faction: faction,
      daoTraces: state.profile.daoTraces,
      insects: state.profile.guInsects,
    );
  }

  /// 尊者级渡劫是否已完成（只读派生，不写 Hive、不改状态）。
  ///
  /// PlayerProfile.tribulations 中存在 realmLevel == 9 且
  /// stageIndex >= kTribulationCompletedStageIndex 的记录时为 true。
  bool get nineTurnTribulationSatisfied => state.profile.tribulations.any(
      (r) => r.realmLevel == 9 && r.stageIndex >= kTribulationCompletedStageIndex);

  /// 九转前置条件（只读派生，不写 Hive、不改状态）。
  ///
  /// 复用 6A 纯逻辑 checkNineTurnPrerequisites，不在此重新实现四条件；
  /// tribulationSatisfied 由 nineTurnTribulationSatisfied 提供。
  NineTurnPrerequisiteResult get nineTurnPrerequisites =>
      checkNineTurnPrerequisites(
        profile: state.profile,
        tribulationSatisfied: nineTurnTribulationSatisfied,
      );

  /// 道主资格（只读派生，不写 Hive、不改状态）。
  ///
  /// 复用 6E-1 纯逻辑 checkDaoZhuEligibility，不复制资格判断公式；
  /// 默认查看流派 = resolvePrimaryFaction（无主修流派时安全返回不可授予）；
  /// isDeepestUnderstanding 恒为 false（不自行推导「当世理解最深」）。
  DaoZhuEligibility get daoZhuEligibility {
    final primary = resolvePrimaryFaction(state.profile);
    if (primary == null) {
      final already = state.profile.daoZhu != null;
      return DaoZhuEligibility(
        nineTurnSatisfied: state.profile.nineTurnReached,
        factionRealmSatisfied: false,
        daoTracesSatisfied: false,
        deepestUnderstandingSatisfied: false,
        alreadyGranted: already,
        canGrant: false,
        failureReason: already ? '已成为道主' : '未指定主修流派',
      );
    }
    return checkDaoZhuEligibility(
      profile: state.profile,
      faction: primary,
    );
  }

  /// 尝试九转突破（持久化九转状态）。
  ///
  /// - 复用 6A 的 checkNineTurnPrerequisites，不复制四条件判断；
  /// - [tribulationSatisfied]：尊者级渡劫是否完成，由调用方传入（6C 实现真正计算）；
  /// - 成功：nineTurnReached=true、nineTurnBreakthroughAt=now、白荔→黄杏质变并保存；
  /// - 已突破：返回 alreadyReached，不重复突破、不重复质变；
  /// - 前置不足：返回 failed，状态与仙元不变。
  NineTurnBreakthroughResult attemptNineTurnBreakthrough({
    required bool tribulationSatisfied,
  }) {
    final profile = state.profile;

    if (profile.nineTurnReached) {
      return const NineTurnBreakthroughResult(
        status: NineTurnBreakthroughStatus.alreadyReached,
        failureReason: '已突破九转',
      );
    }

    final prerequisite = checkNineTurnPrerequisites(
      profile: profile,
      tribulationSatisfied: tribulationSatisfied,
    );
    if (!prerequisite.canBreakthrough) {
      return NineTurnBreakthroughResult(
        status: NineTurnBreakthroughStatus.failed,
        failureReason: _nineTurnFailureReason(prerequisite),
        xianYuanAfter: profile.xianYuan,
      );
    }

    profile.nineTurnReached = true;
    profile.nineTurnBreakthroughAt = DateTime.now();
    profile.xianYuan = XianYuanType.huangxing.index;
    saveProfile(profile);

    return NineTurnBreakthroughResult(
      status: NineTurnBreakthroughStatus.succeeded,
      nineTurnBreakthroughAt: profile.nineTurnBreakthroughAt,
      xianYuanAfter: profile.xianYuan,
    );
  }

  String _nineTurnFailureReason(NineTurnPrerequisiteResult r) {
    if (!r.daoTracesSatisfied) return '主修流派道痕不足';
    if (!r.factionRealmSatisfied) return '主修流派境界未达无上大宗师';
    if (!r.xianYuanSatisfied) return '仙元不是白荔仙元';
    if (!r.tribulationSatisfied) return '未完成尊者级渡劫';
    return '九转前置条件未满足';
  }

  /// 显式授予道主（持久化 daoZhu）。
  ///
  /// - 复用 6E-1 纯逻辑 checkDaoZhuEligibility，不复制资格判断公式；
  /// - 已授予：返回 alreadyGranted，绝不覆盖原 daoZhu（即使传入不同 faction/eraId/now）；
  /// - 资格不足：返回 failed + failureReason，不创建、不修改、不保存；
  /// - 成功：写入 profile.daoZhu = DaoZhuState(faction, crownedAt, eraId) 并 saveProfile；
  /// - 只新增 daoZhu，绝不修改 nineTurnReached / nineTurnBreakthroughAt / xianYuan /
  ///   daoTraces / factionRealmExp / currentCultivation / totalXp / tribulations /
  ///   guInsects / guMaterials 等其他字段。
  DaoZhuGrantResult grantDaoZhu({
    required Faction faction,
    required bool isDeepestUnderstanding,
    String? eraId,
    DateTime? now,
  }) {
    final profile = state.profile;
    final eligibility = checkDaoZhuEligibility(
      profile: profile,
      faction: faction,
      isDeepestUnderstanding: isDeepestUnderstanding,
    );

    if (eligibility.alreadyGranted) {
      return DaoZhuGrantResult(
        status: DaoZhuGrantStatus.alreadyGranted,
        failureReason: eligibility.failureReason,
      );
    }
    if (!eligibility.canGrant) {
      return DaoZhuGrantResult(
        status: DaoZhuGrantStatus.failed,
        failureReason: eligibility.failureReason ?? '道主资格未满足',
      );
    }

    final crownedAt = now ?? DateTime.now();
    profile.daoZhu = DaoZhuState(
      faction: faction.index,
      crownedAt: crownedAt,
      eraId: eraId ?? '',
    );
    saveProfile(profile);

    return DaoZhuGrantResult(
      status: DaoZhuGrantStatus.succeeded,
      daoZhu: profile.daoZhu,
      crownedAt: crownedAt,
    );
  }

  /// 当前转数（由 statsBox totalXp 派生；累计修为唯一权威）。
  int get currentRealmLevel {
    final totalXp = statsBox.get('totalXp', defaultValue: 0) as int;
    return getRealmProgress(totalXp).level;
  }

  /// 距下一劫难的修为差（当前修为为准；无下一劫难为 0）。
  int get tribulationDistance => distanceToNextTribulation(
        currentCultivation: state.profile.currentCultivation,
        tribulations: state.profile.tribulations,
      );

  /// 已度过劫难总次数（六/七/八/九转合计）。
  int get tribulationsPassedTotal =>
      totalPassedTribulations(state.profile.tribulations);

  /// 当前转数「已到期且未渡过」的 stage（0/1/2）；无则 null。
  int? get dueTribulationStageForCurrentRealm =>
      dueTribulationStage(
        realmLevel: currentRealmLevel,
        currentCultivation: state.profile.currentCultivation,
        tribulations: state.profile.tribulations,
      );

  /// 指定转数「已到期且未渡过」的 stage（供渡劫卡各转行展示）。
  int? dueTribulationStageFor(int realmLevel) => dueTribulationStage(
        realmLevel: realmLevel,
        currentCultivation: state.profile.currentCultivation,
        tribulations: state.profile.tribulations,
      );

  /// 尝试渡劫（持久化渡劫状态）。
  ///
  /// - 复用 TribulationService 纯逻辑，不复制成功率/惩罚公式；
  /// - [now] / [random] 为测试钩子（时间与随机可注入）；
  /// - 失败：failCount++、lastAttemptAt=now、currentCultivation -= 目标转数跨度/3（clamp≥0）；
  /// - 成功：推进小阶（普通 0→1→2→3、尊者 0→3），failCount 重置 0，lastAttemptAt=now；
  /// - 冷却中 / 非法参数：不写 Hive、不改状态；
  /// - 绝不修改 totalXp / daoTraces / factionRealmExp / nineTurnReached / xianYuan / daoZhu。
  tribulation.TribulationResult attemptTribulation({
    required int realmLevel,
    required int stageIndex,
    DateTime? now,
    Random? random,
  }) {
    final profile = state.profile;
    final nowDt = now ?? DateTime.now();

    // 查找 (realmLevel, stageIndex) 记录；历史重复 key 取第一条有效记录
    final existing = profile.tribulations
        .where((r) => r.realmLevel == realmLevel && r.stageIndex == stageIndex)
        .firstOrNull;
    final failCount = existing?.failCount ?? 0;
    final lastAttemptAt = existing?.lastAttemptAt;

    final result = tribulation.attemptTribulation(
      realmLevel: realmLevel,
      stageIndex: stageIndex,
      failCount: failCount,
      now: nowDt,
      realmSpan: tribulationRealmSpan(realmLevel),
      lastAttemptAt: lastAttemptAt,
      random: random,
    );

    // 冷却 / 非法：不写 Hive、不改状态
    if (result.outcome == tribulation.TribulationOutcome.invalid ||
        result.outcome == tribulation.TribulationOutcome.onCooldown) {
      return result;
    }

    if (!result.success) {
      // 失败：failCount++、lastAttemptAt=now、currentCultivation 扣减（clamp≥0）
      if (existing != null) {
        existing.failCount = result.failCount;
        existing.lastAttemptAt = nowDt;
      } else {
        profile.tribulations.add(TribulationRecord(
          realmLevel: realmLevel,
          stageIndex: stageIndex,
          failCount: result.failCount,
          lastAttemptAt: nowDt,
        ));
      }
      profile.currentCultivation =
          max(0, profile.currentCultivation - result.cultivationPenalty);
      saveProfile(profile);
      return result;
    }

    // 成功：移除当前 stage 记录（含历史重复），写入唯一 nextStageIndex 记录
    profile.tribulations.removeWhere(
        (r) => r.realmLevel == realmLevel && r.stageIndex == stageIndex);
    profile.tribulations.add(TribulationRecord(
      realmLevel: realmLevel,
      stageIndex: result.nextStageIndex,
      failCount: result.failCount, // 成功 → 0
      lastAttemptAt: nowDt,
    ));
    saveProfile(profile);
    return result;
  }
}

final cultivationProvider =
    StateNotifierProvider<CultivationNotifier, CultivationState>((ref) {
  final box = ref.watch(cultivationBoxProvider);
  final statsBox = Hive.box('stats');
  return CultivationNotifier(box, statsBox);
});
