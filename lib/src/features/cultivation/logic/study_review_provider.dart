// 学习回顾 Provider —— 提供周/月/近7日/学科 学习回顾。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session_box_provider.dart';
import 'cultivation_session_provider.dart';
import 'study_review_service.dart';

/// 学习回顾（会话变化时重算）。
final studyReviewProvider = Provider<StudyReview>((ref) {
  ref.watch(cultivationSessionProvider);
  final box = ref.watch(sessionBoxProvider);
  return computeStudyReview(box.values.toList(), DateTime.now());
});
