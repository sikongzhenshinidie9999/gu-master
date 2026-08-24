// 成就 Provider —— 提供成就解锁状态。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session_box_provider.dart';
import 'achievement_service.dart';
import 'cultivation_session_provider.dart';

/// 成就列表（会话变化时重算）。
final achievementProvider = Provider<List<Achievement>>((ref) {
  ref.watch(cultivationSessionProvider);
  final box = ref.watch(sessionBoxProvider);
  return computeAchievements(box.values.toList());
});
