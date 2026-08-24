import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import 'package:sidequest/src/features/cultivation/data/cultivation_session.dart';
import 'package:sidequest/src/features/cultivation/data/dao_zhu.dart';
import 'package:sidequest/src/features/cultivation/data/gu_insect.dart';
import 'package:sidequest/src/features/cultivation/data/gu_material.dart';
import 'package:sidequest/src/features/cultivation/data/player_profile.dart';
import 'package:sidequest/src/features/cultivation/data/session_box_provider.dart';
import 'package:sidequest/src/features/cultivation/data/tribulation_record.dart';
import 'package:sidequest/src/features/cultivation/logic/cultivation_provider.dart';
import 'package:sidequest/src/features/quests/data/quest_model.dart';
import 'package:sidequest/src/features/quests/logic/quest_provider.dart';
import 'package:sidequest/src/features/quests/presentation/screens/the_board_screen.dart';

void main() {
  // TypeAdapter 全局只注册一次
  Hive.registerAdapter(QuestModelAdapter()); // typeId 0
  Hive.registerAdapter(PlayerProfileAdapter()); // typeId 1
  Hive.registerAdapter(TribulationRecordAdapter()); // typeId 2
  Hive.registerAdapter(GuInsectAdapter()); // typeId 3
  Hive.registerAdapter(GuMaterialAdapter()); // typeId 4
  Hive.registerAdapter(DaoZhuStateAdapter()); // typeId 5
  Hive.registerAdapter(CultivationSessionAdapter()); // typeId 6

  late Directory tempDir;
  late Box<PlayerProfile> cultivationBox;
  late Box<CultivationSession> sessionBox;
  late Box<QuestModel> questBox;
  late ProviderContainer container;

  tearDown(() {
    container.dispose();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  // Hive 的异步文件 I/O 在 testWidgets 的伪异步下会挂起，统一使用内存后端。
  Future<void> initEnv(WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(() async {
      await Hive.close();
      try {
        await Hive.deleteFromDisk();
      } catch (_) {}
      tempDir = await Directory.systemTemp.createTemp('seclusion_entry_test_');
      Hive.init(tempDir.path);
      cultivationBox =
          await Hive.openBox<PlayerProfile>('cultivation', bytes: Uint8List(0));
      sessionBox = await Hive.openBox<CultivationSession>(
          'sessions',
          bytes: Uint8List(0));
      questBox =
          await Hive.openBox<QuestModel>('quests', bytes: Uint8List(0));
      await Hive.openBox('stats', bytes: Uint8List(0));
      await Hive.openBox('settings', bytes: Uint8List(0));
    });
    container = ProviderContainer(overrides: [
      questBoxProvider.overrideWithValue(questBox),
      cultivationBoxProvider.overrideWithValue(cultivationBox),
      sessionBoxProvider.overrideWithValue(sessionBox),
    ]);
  }

  Future<void> pumpBoard(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: TheBoardScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('首页存在闭关入口', (tester) async {
    await initEnv(tester);
    await pumpBoard(tester);
    expect(find.text('开始闭关'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // 卸载树，避免遗留 Timer
  });

  testWidgets('点击闭关入口进入 SeclusionScreen', (tester) async {
    await initEnv(tester);
    await pumpBoard(tester);
    await tester.ensureVisible(find.text('开始闭关'));
    await tester.pump();
    await tester.tap(find.text('开始闭关'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // 路由动画

    expect(find.text('今日闭关'), findsOneWidget); // SeclusionScreen 已进入
    // 首页入口仍在树中（同时闭关页开始卡片也有「开始闭关」标题，故用 findsWidgets）
    expect(find.text('开始闭关'), findsWidgets);
    await tester.pumpWidget(const SizedBox()); // 卸载树，避免遗留 Timer
  });
}
