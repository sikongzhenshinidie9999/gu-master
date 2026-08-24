import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sidequest/src/features/quests/data/quest_model.dart';

import '../data/player_profile.dart';
import 'reward_calculator.dart';

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
/// 职责：读取 / 初始化 / 保存玩家档案，并提供未来扩展入口。
/// 本阶段不接入任务奖励、渡劫、炼蛊等玩法。
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
  /// - 不影响 totalXp；无奖励的分类（杂务 / 炼气等）直接跳过。
  void applyQuestCompletedRewards(QuestModel quest) {
    final reward = computeCultivationReward(quest);
    if (!reward.hasDaoTrace && !reward.hasRealmExp) return;
    final profile = state.profile;
    final kind = reward.daoKind!;
    if (reward.hasDaoTrace) {
      profile.daoTraces[kind.index] =
          (profile.daoTraces[kind.index] ?? 0) + reward.daoTraceAmount;
    }
    if (reward.hasRealmExp) {
      profile.factionRealmExp[kind.index] =
          (profile.factionRealmExp[kind.index] ?? 0) + reward.realmExpGain;
    }
    saveProfile(profile);
  }

  // —— 未来扩展入口（后续阶段实现）——
  // void attemptTribulation(...) {}
  // void refineGuInsect(...) {}
}

final cultivationProvider =
    StateNotifierProvider<CultivationNotifier, CultivationState>((ref) {
  final box = ref.watch(cultivationBoxProvider);
  final statsBox = Hive.box('stats');
  return CultivationNotifier(box, statsBox);
});
