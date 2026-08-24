import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sidequest/src/features/quests/data/quest_model.dart';
import 'package:uuid/uuid.dart';

import '../data/dao.dart';
import '../data/gu_insect.dart';
import '../data/gu_material.dart';
import '../data/gu_recipe.dart';
import '../data/player_profile.dart';
import '../data/tribulation_record.dart';
import 'faction_realm.dart';
import 'gu_power_service.dart';
import 'nine_turn_prerequisites.dart';
import 'material_drop_service.dart';
import 'refining_config.dart';
import 'refining_service.dart' as refining;
import 'reward_calculator.dart';
import 'tribulation_config.dart';
import 'tribulation_service.dart' as tribulation;

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
  /// - 道痕（力量）与流派感悟（境界成长）分别写入两个独立数据源，互不换算；
  /// - 附加蛊材掉落（每日上限由 stats Box 记录，见 _applyMaterialDrop）；
  /// - 不影响 totalXp、streak、weeklyHistory 与任务完成主流程。
  ///
  /// [random] / [materialDropTurn] 为测试钩子：掉落随机可注入、掉落转数可覆盖。
  void applyQuestCompletedRewards(
    QuestModel quest, {
    Random? random,
    int? materialDropTurn,
  }) {
    final reward = computeCultivationReward(quest);
    final profile = state.profile;
    var changed = false;

    final kind = reward.daoKind;
    if (reward.hasDaoTrace && kind != null) {
      profile.daoTraces[kind.index] =
          (profile.daoTraces[kind.index] ?? 0) + reward.daoTraceAmount;
      changed = true;
    }
    if (reward.hasRealmExp && kind != null) {
      profile.factionRealmExp[kind.index] =
          (profile.factionRealmExp[kind.index] ?? 0) + reward.realmExpGain;
      changed = true;
    }
    if (_applyMaterialDrop(profile, random: random, turn: materialDropTurn)) {
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
