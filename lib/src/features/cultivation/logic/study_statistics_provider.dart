// 学习统计 Provider —— 提供今日/本周/累计学习数据与连续天数。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/session_box_provider.dart';
import 'cultivation_session_provider.dart';
import 'study_statistics_service.dart';

/// 学习统计（会话变化时重算；studyStreak 从 statsBox 读取）。
final studyStatisticsProvider = Provider<StudyStatistics>((ref) {
  ref.watch(cultivationSessionProvider); // 会话生命周期变化时重算
  final box = ref.watch(sessionBoxProvider);
  final stats = computeStudyStatistics(box.values.toList(), DateTime.now());
  final streak = Hive.box('stats').get('studyStreak', defaultValue: 0) as int;
  return stats.copyWith(studyStreak: streak);
});
