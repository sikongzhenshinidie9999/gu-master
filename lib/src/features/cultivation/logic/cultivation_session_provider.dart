// 闭关（番茄钟）Provider —— 管理 session 生命周期与奖励结算。
//
// 学习打卡系统：番茄钟服务学习行为，蛊师体系只是趣味反馈。
// - totalXp 唯一权威来源 = statsBox['totalXp']（与任务共用同一 key，不写 PlayerProfile.totalXp）；
// - 奖励计算复用 computeSessionReward / applyCultivationGains，不复制公式；
// - 运行/暂停为内存态，完成/取消才持久化到 sessions Box。

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/cultivation_session.dart';
import '../data/session_box_provider.dart';
import 'cultivation_provider.dart';
import 'session_reward_calculator.dart';
import 'session_reward_config.dart';
import 'study_goal_service.dart';

/// 判断两个日期是否为同一天。
bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 闭关状态。
class CultivationSessionState {
  const CultivationSessionState({
    this.currentSession,
    this.todaySessions = const [],
  });

  /// 当前进行中的闭关（running/paused；内存态，未持久化）。
  final CultivationSession? currentSession;

  /// 今日闭关记录（来自 sessions Box，含完成与取消）。
  final List<CultivationSession> todaySessions;
}

/// 闭关领域 Notifier。
class CultivationSessionNotifier
    extends StateNotifier<CultivationSessionState> {
  final Box<CultivationSession> sessionBox;
  final Box<dynamic> statsBox;
  final CultivationNotifier cultivationNotifier;

  CultivationSessionNotifier(
    this.sessionBox,
    this.statsBox,
    this.cultivationNotifier,
  ) : super(CultivationSessionState(
          todaySessions: _loadTodaySessions(sessionBox, DateTime.now()),
        ));

  /// 今日累计修为（只读；取消/未完成 session 的 xp 为 0）。
  int get todayXp =>
      state.todaySessions.fold(0, (sum, s) => sum + s.xpEarned);

  /// 今日已完成学习分钟（从 sessions 派生，不单独保存）。
  int get todayStudyMinutes =>
      getTodayStudyMinutes(state.todaySessions, DateTime.now());

  /// 每日学习目标（分钟；statsBox 配置，默认 120）。
  int get dailyStudyGoalMinutes =>
      statsBox.get('dailyStudyGoalMinutes', defaultValue: 120) as int;

  /// 今日目标进度（0~100%）。
  int get todayGoalProgress => calculateGoalProgress(
        current: todayStudyMinutes,
        goal: dailyStudyGoalMinutes,
      );

  /// 学习连续打卡天数（statsBox）。
  int get studyStreak => statsBox.get('studyStreak', defaultValue: 0) as int;

  static List<CultivationSession> _loadTodaySessions(
      Box<CultivationSession> box, DateTime now) {
    return box.values.where((s) => _isSameDay(s.startTime, now)).toList();
  }

  /// 日期键（yyyy-MM-dd）。
  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 更新学习连续打卡（仅成功完成闭关时调用）。
  ///
  /// - 无 lastStudyDate → studyStreak = 1；
  /// - lastStudyDate = 今天 → 不增加（同一天多次只算一天）；
  /// - lastStudyDate = 昨天 → studyStreak + 1；
  /// - 断档超过一天 → studyStreak = 1。
  /// 写入 statsBox 的 studyStreak / lastStudyDate（String yyyy-MM-dd），
  /// 不影响 totalXp / daoTraces / factionRealmExp / session 记录。
  Future<void> _updateStudyStreak(DateTime now) async {
    final today = _dateKey(now);
    final last = statsBox.get('lastStudyDate') as String?;
    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));
    final currentStreak = statsBox.get('studyStreak', defaultValue: 0) as int;

    int newStreak;
    if (last == null) {
      newStreak = 1;
    } else if (last == today) {
      newStreak = currentStreak <= 0 ? 1 : currentStreak;
    } else if (last == yesterday) {
      newStreak = currentStreak + 1;
    } else {
      newStreak = 1;
    }

    await statsBox.put('studyStreak', newStreak);
    await statsBox.put('lastStudyDate', today);
  }

  /// 开始闭关（创建 running 内存态 session；已有进行中 session 时忽略）。
  void startSession({
    required String subject,
    required int plannedDurationMinutes,
    DateTime? now,
  }) {
    if (state.currentSession != null) return;
    final startTime = now ?? DateTime.now();
    final session = CultivationSession(
      id: const Uuid().v4(),
      startTime: startTime,
      endTime: null,
      plannedDurationMinutes: plannedDurationMinutes,
      actualDurationMinutes: 0,
      subject: subject,
      category: kSubjectCategoryMap[subject]?.index ??
          CultivationSessionCategory.misc.index,
      status: CultivationSessionStatus.running.index,
    );
    state = CultivationSessionState(
      currentSession: session,
      todaySessions: state.todaySessions,
    );
  }

  /// 暂停闭关（running → paused）。
  void pauseSession() {
    final current = state.currentSession;
    if (current == null ||
        current.status != CultivationSessionStatus.running.index) {
      return;
    }
    state = CultivationSessionState(
      currentSession:
          current.copyWith(status: CultivationSessionStatus.paused.index),
      todaySessions: state.todaySessions,
    );
  }

  /// 恢复闭关（paused → running）。
  void resumeSession() {
    final current = state.currentSession;
    if (current == null ||
        current.status != CultivationSessionStatus.paused.index) {
      return;
    }
    state = CultivationSessionState(
      currentSession:
          current.copyWith(status: CultivationSessionStatus.running.index),
      todaySessions: state.todaySessions,
    );
  }

  /// 完成闭关：结算奖励并持久化。
  ///
  /// - 实际分钟 = endTime - startTime（负数按 0）；
  /// - 奖励来自 computeSessionReward（纯逻辑）；
  /// - 修为写入 statsBox['totalXp']（唯一权威，不写 PlayerProfile.totalXp）；
  /// - 道痕/感悟/蛊材经 applyCultivationGains（共享入口）；
  /// - 生成 completed 记录保存到 sessions Box；currentSession 清空。
  Future<void> completeSession({DateTime? now, Random? random}) async {
    final current = state.currentSession;
    if (current == null) return;
    if (current.status != CultivationSessionStatus.running.index &&
        current.status != CultivationSessionStatus.paused.index) {
      return; // 重复 complete / 已结束 防护
    }
    final endTime = now ?? DateTime.now();
    final elapsed = endTime.difference(current.startTime).inMinutes;
    final actualMinutes = elapsed < 0 ? 0 : elapsed;

    final reward = computeSessionReward(
      subject: current.subject,
      actualMinutes: actualMinutes,
      random: random,
    );

    // 修炼奖励（当前修为 + 道痕/感悟/蛊材；totalXp 由本 Provider 写 statsBox）
    cultivationNotifier.applyCultivationGains(
      daoKind: reward.daoKind,
      daoTraceAmount: reward.daoTraceAmount,
      realmExpGain: reward.realmExp,
      currentCultivationGain: reward.xp,
      random: random,
    );

    // totalXp：statsBox 唯一权威
    final oldXp = statsBox.get('totalXp', defaultValue: 0) as int;
    await statsBox.put('totalXp', oldXp + reward.xp);

    final completed = current.copyWith(
      endTime: endTime,
      actualDurationMinutes: actualMinutes,
      status: CultivationSessionStatus.completed.index,
      xpEarned: reward.xp,
      daoTraceKind: reward.daoKind?.index,
      daoTraceAmount: reward.daoTraceAmount,
      realmExpEarned: reward.realmExp,
    );
    await sessionBox.add(completed);

    // 学习连续打卡（成功完成才计一天；取消不计）
    await _updateStudyStreak(endTime);

    state = CultivationSessionState(
      currentSession: null,
      todaySessions: _loadTodaySessions(sessionBox, endTime),
    );
  }

  /// 取消闭关：不发奖励，持久化 cancelled 记录后清空 current。
  Future<void> cancelSession({DateTime? now}) async {
    final current = state.currentSession;
    if (current == null) return;
    if (current.status != CultivationSessionStatus.running.index &&
        current.status != CultivationSessionStatus.paused.index) {
      return;
    }
    final cancelTime = now ?? DateTime.now();
    final cancelled = current.copyWith(
      endTime: cancelTime,
      status: CultivationSessionStatus.cancelled.index,
      xpEarned: 0,
      daoTraceKind: null,
      daoTraceAmount: 0,
      realmExpEarned: 0,
    );
    await sessionBox.add(cancelled);

    state = CultivationSessionState(
      currentSession: null,
      todaySessions: _loadTodaySessions(sessionBox, cancelTime),
    );
  }
}

/// 闭关 Provider。
final cultivationSessionProvider =
    StateNotifierProvider<CultivationSessionNotifier, CultivationSessionState>(
        (ref) {
  final box = ref.watch(sessionBoxProvider);
  final statsBox = Hive.box('stats');
  // 只读一次 notifier（稳定实例），避免因 cultivation state 变化重建本 Provider
  final cultivation = ref.read(cultivationProvider.notifier);
  return CultivationSessionNotifier(box, statsBox, cultivation);
});
