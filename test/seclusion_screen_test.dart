import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:sidequest/src/features/cultivation/data/cultivation_session.dart';
import 'package:sidequest/src/features/cultivation/data/dao_zhu.dart';
import 'package:sidequest/src/features/cultivation/data/gu_insect.dart';
import 'package:sidequest/src/features/cultivation/data/gu_material.dart';
import 'package:sidequest/src/features/cultivation/data/player_profile.dart';
import 'package:sidequest/src/features/cultivation/data/session_box_provider.dart';
import 'package:sidequest/src/features/cultivation/data/tribulation_record.dart';
import 'package:sidequest/src/features/cultivation/logic/cultivation_provider.dart';
import 'package:sidequest/src/features/cultivation/logic/cultivation_session_provider.dart';
import 'package:sidequest/src/features/cultivation/presentation/screens/seclusion_screen.dart';
import 'package:sidequest/src/features/quests/data/quest_model.dart';
import 'package:sidequest/src/features/quests/logic/quest_provider.dart';

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
    await tester.runAsync(() async {
      await Hive.close();
      try {
        await Hive.deleteFromDisk();
      } catch (_) {}
      tempDir = await Directory.systemTemp.createTemp('seclusion_screen_test_');
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

  Future<void> pumpSeclusion(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SeclusionScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('页面显示今日闭关汇总', (tester) async {
    await initEnv(tester);
    await pumpSeclusion(tester);
    expect(find.text('今日闭关'), findsOneWidget);
    expect(find.text('学习次数'), findsOneWidget);
    expect(find.text('学习分钟'), findsOneWidget);
    expect(find.text('获得修为'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3)); // 次数/分钟/修为初始为 0
  });

  testWidgets('学科按钮存在', (tester) async {
    await initEnv(tester);
    await pumpSeclusion(tester);
    for (final s in ['数学', '英语', '408', '专业课', '其他']) {
      expect(find.text(s), findsOneWidget, reason: '学科 $s 应存在');
    }
  });

  testWidgets('时间按钮存在（25/45/90 分钟）', (tester) async {
    await initEnv(tester);
    await pumpSeclusion(tester);
    expect(find.text('25 分钟'), findsOneWidget);
    expect(find.text('45 分钟'), findsOneWidget);
    expect(find.text('90 分钟'), findsOneWidget);
  });

  testWidgets('点击时间按钮调用 startSession', (tester) async {
    await initEnv(tester);
    await pumpSeclusion(tester);
    await tester.ensureVisible(find.text('25 分钟'));
    await tester.pump();
    await tester.tap(find.text('25 分钟'));
    await tester.pump();

    final current =
        container.read(cultivationSessionProvider).currentSession;
    expect(current, isNotNull);
    expect(current!.subject, '数学'); // 默认学科
    expect(current.plannedDurationMinutes, 25);
    expect(current.status, CultivationSessionStatus.running.index);
    // UI 切换到进行中
    expect(find.text('进行中'), findsOneWidget);
    expect(find.text('当前学科：数学'), findsOneWidget);
  });

  testWidgets('完成后显示奖励反馈 SnackBar', (tester) async {
    await initEnv(tester);
    await pumpSeclusion(tester);
    await tester.ensureVisible(find.text('25 分钟'));
    await tester.pump();
    await tester.tap(find.text('25 分钟'));
    await tester.pump();

    await tester.ensureVisible(find.text('完成闭关'));
    await tester.pump();
    await tester.tap(find.text('完成闭关'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('闭关完成'), findsOneWidget);
    expect(container.read(cultivationSessionProvider).currentSession, isNull);
    expect(container.read(cultivationSessionProvider).todaySessions.length, 1);
    expect(find.text('今日记录'), findsOneWidget);
  });

  testWidgets('显示今日闭关目标卡（默认 120 分钟）', (tester) async {
    await initEnv(tester);
    await pumpSeclusion(tester);
    expect(find.text('今日闭关目标'), findsOneWidget);
    expect(find.text('目标：120 分钟'), findsOneWidget);
    expect(find.text('已完成：0 分钟'), findsOneWidget);
    expect(find.text('连续修炼：0 天'), findsOneWidget);
  });

  testWidgets('目标卡显示已完成分钟与进度', (tester) async {
    await initEnv(tester);
    // 种子一条今天完成的 session（25 分钟 → 进度 20%）
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 8);
    final session = CultivationSession(
      id: 's1',
      startTime: today,
      endTime: today.add(const Duration(minutes: 25)),
      plannedDurationMinutes: 25,
      actualDurationMinutes: 25,
      subject: '英语',
      category: CultivationSessionCategory.shen.index,
      status: CultivationSessionStatus.completed.index,
      xpEarned: 50,
      daoTraceKind: 2,
      daoTraceAmount: 25,
      realmExpEarned: 25,
    );
    await tester.runAsync(() => sessionBox.add(session));
    await pumpSeclusion(tester);

    expect(find.text('今日闭关目标'), findsOneWidget);
    expect(find.text('已完成：25 分钟'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator));
    expect(bar.value, closeTo(0.2, 0.001)); // 25*100~/120 = 20%
  });
}
