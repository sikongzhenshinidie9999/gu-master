import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'cultivation_session.dart';

/// sessions Box Provider（由 main.dart 注入）。
///
/// 以后 Provider 层通过它访问闭关记录；UI 不直接使用 Hive。
final sessionBoxProvider = Provider<Box<CultivationSession>>((ref) {
  throw UnimplementedError('sessionBoxProvider not initialized');
});
