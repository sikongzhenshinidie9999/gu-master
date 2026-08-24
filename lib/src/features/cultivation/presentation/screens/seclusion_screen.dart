// 闭关页面（番茄钟学习打卡）。
//
// 简单、稳定、快速使用；倒计时仅 UI 层，不修改 session 数据。
// 所有数据来自 CultivationSessionProvider；UI 不直接操作 Hive、不复制奖励公式。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidequest/src/features/cultivation/data/cultivation_session.dart';
import 'package:sidequest/src/features/cultivation/logic/cultivation_session_provider.dart';
import 'package:sidequest/src/features/cultivation/logic/session_reward_config.dart';
import 'package:sidequest/src/shared/widgets/app_snackbar.dart';
import 'package:sidequest/src/shared/widgets/glass_card.dart';
import 'package:intl/intl.dart';

/// 闭关页面（番茄钟）。
class SeclusionScreen extends ConsumerStatefulWidget {
  const SeclusionScreen({super.key});

  @override
  ConsumerState<SeclusionScreen> createState() => _SeclusionScreenState();
}

class _SeclusionScreenState extends ConsumerState<SeclusionScreen> {
  static const List<String> _subjects = ['数学', '英语', '408', '专业课', '其他'];

  String _selectedSubject = '数学';
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker(bool active) {
    if (active && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    } else if (!active && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  String _formatRemaining(CultivationSession session) {
    final elapsed = _now.difference(session.startTime);
    final planned = Duration(minutes: session.plannedDurationMinutes);
    final remaining = planned - elapsed;
    final totalSec = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _complete() async {
    await ref.read(cultivationSessionProvider.notifier).completeSession();
    if (!mounted) return;
    final notifier = ref.read(cultivationSessionProvider.notifier);
    if (notifier.todayGoalProgress >= 100) {
      showAppSnackBar(context, '今日闭关圆满');
      return;
    }
    final sessions = ref.read(cultivationSessionProvider).todaySessions;
    final last = sessions.isEmpty ? null : sessions.last;
    final xp = last?.xpEarned ?? 0;
    final dao = last?.daoTraceAmount ?? 0;
    showAppSnackBar(
      context,
      dao > 0 ? '闭关完成，获得修为 $xp，道痕 +$dao' : '闭关完成，获得修为 $xp',
    );
  }

  Future<void> _cancel() async {
    await ref.read(cultivationSessionProvider.notifier).cancelSession();
  }

  @override
  Widget build(BuildContext context) {
    // 监听 currentSession 变化，同步 UI 层倒计时 ticker（不修改 session 数据）
    ref.listen<CultivationSessionState>(
      cultivationSessionProvider,
      (prev, next) => _syncTicker(next.currentSession != null),
    );
    final state = ref.watch(cultivationSessionProvider);
    _syncTicker(state.currentSession != null);
    final current = state.currentSession;
    final totalMinutes =
        state.todaySessions.fold<int>(0, (a, s) => a + s.actualDurationMinutes);
    final todayXp =
        state.todaySessions.fold<int>(0, (a, s) => a + s.xpEarned);
    final goalNotifier = ref.read(cultivationSessionProvider.notifier);
    final todayMinutes = goalNotifier.todayStudyMinutes;
    final goal = goalNotifier.dailyStudyGoalMinutes;
    final goalProgress = goalNotifier.todayGoalProgress;
    final streak = goalNotifier.studyStreak;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          '闭关',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildGoalCard(todayMinutes, goal, goalProgress, streak),
          const SizedBox(height: 20),
          _buildTodaySummary(state, totalMinutes, todayXp),
          const SizedBox(height: 20),
          if (current == null)
            _buildStartCard()
          else
            _buildActiveCard(current),
          const SizedBox(height: 20),
          _buildTodayList(state),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(int todayMinutes, int goal, int progress, int streak) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flag_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                '今日闭关目标',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('目标：$goal 分钟',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
              Text('已完成：$todayMinutes 分钟',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: goal <= 0 ? 0 : (progress / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text('连续修炼：$streak 天',
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTodaySummary(
      CultivationSessionState state, int totalMinutes, int todayXp) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timer_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                '今日闭关',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat('学习次数', state.todaySessions.length),
              _stat('学习分钟', totalMinutes),
              _stat('获得修为', todayXp),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildStartCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '开始闭关',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text('选择学科', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final s in _subjects)
                ChoiceChip(
                  label: Text(s),
                  selected: _selectedSubject == s,
                  onSelected: (_) => setState(() => _selectedSubject = s),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('选择时长', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < kSessionPresetMinutes.length; i++) ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ref
                          .read(cultivationSessionProvider.notifier)
                          .startSession(
                            subject: _selectedSubject,
                            plannedDurationMinutes: kSessionPresetMinutes[i],
                          );
                    },
                    child: Text('${kSessionPresetMinutes[i]} 分钟'),
                  ),
                ),
                if (i < kSessionPresetMinutes.length - 1)
                  const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(CultivationSession current) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '进行中',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text('当前学科：${current.subject}'),
          Text('开始时间：${DateFormat('HH:mm').format(current.startTime)}'),
          Text('剩余时间：${_formatRemaining(current)}'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _complete,
                  child: const Text('完成闭关'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancel,
                  child: const Text('取消闭关'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayList(CultivationSessionState state) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今日记录',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (state.todaySessions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '今天还没有闭关记录',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.todaySessions.length,
              itemBuilder: (context, index) {
                final s = state.todaySessions[index];
                final statusLabel = s.status == CultivationSessionStatus.completed.index
                    ? '完成'
                    : '取消';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${s.subject} · ${DateFormat('HH:mm').format(s.startTime)} · $statusLabel',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        '+${s.xpEarned} 修为',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
