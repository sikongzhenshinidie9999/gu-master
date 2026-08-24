// 个人挑战 Provider —— 提供个人历史最高纪录。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session_box_provider.dart';
import 'challenge_service.dart';
import 'cultivation_session_provider.dart';

/// 个人挑战（会话变化时重算）。
final challengeProvider = Provider<ChallengeSummary>((ref) {
  ref.watch(cultivationSessionProvider);
  final box = ref.watch(sessionBoxProvider);
  return computeChallenges(box.values.toList(), DateTime.now());
});
