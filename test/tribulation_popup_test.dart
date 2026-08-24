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
import 'package:sidequest/src/shared/widgets/nav_scaffold.dart';

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

  Future<void> initEnv(WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(() async {
      await Hive.close();
      try {
        await Hive.deleteFromDisk();
      } catch (_) {}
      tempDir = await Directory.systemTemp.createTemp('tribulation_popup_test_');
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

  Future<void> pumpNav(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NavScaffold()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('修为跨里程碑自动弹出劫难弹窗（仅可渡劫）', (tester) async {
    await initEnv(tester);
    // 六转（totalXp 3000 → realm 6），当前修为 2832 < 里程碑 2833
    await tester.runAsync(() => Hive.box('stats').put('totalXp', 3000));
    final profile = PlayerProfile(currentCultivation: 2832);
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpNav(tester);
    expect(find.text('劫难已至'), findsNothing);

    // 任务/修炼增加修为跨过里程碑
    container.read(cultivationProvider.notifier).applyCultivationGains(
          daoKind: null,
          daoTraceAmount: 0,
          realmExpGain: 0,
          currentCultivationGain: 100,
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 弹窗出现，且只能点击渡劫（无取消/关闭）
    expect(find.text('劫难已至'), findsOneWidget);
    expect(find.textContaining('劫难降临'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '渡劫'), findsWidgets);
    expect(find.text('取消'), findsNothing);
    expect(find.text('关闭'), findsNothing);

    await tester.pumpWidget(const SizedBox()); // 卸载树，避免遗留 Timer
  });

  testWidgets('已渡过劫难后不再弹出', (tester) async {
    await initEnv(tester);
    await tester.runAsync(() => Hive.box('stats').put('totalXp', 3000));
    final profile = PlayerProfile(
      currentCultivation: 2900, // 已跨 2833，但 stage0 已渡过
      tribulations: [TribulationRecord(realmLevel: 6, stageIndex: 1)],
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpNav(tester);
    await tester.pump(const Duration(milliseconds: 100));
    // 六转 stage0 已渡过 → 无到期 → 不弹窗
    expect(find.text('劫难已至'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
