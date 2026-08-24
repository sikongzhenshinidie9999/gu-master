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
import 'faction_realm.dart';
import 'material_drop_service.dart';
import 'refining_config.dart';
import 'refining_service.dart' as refining;
import 'reward_calculator.dart';

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
}

final cultivationProvider =
    StateNotifierProvider<CultivationNotifier, CultivationState>((ref) {
  final box = ref.watch(cultivationBoxProvider);
  final statsBox = Hive.box('stats');
  return CultivationNotifier(box, statsBox);
});
