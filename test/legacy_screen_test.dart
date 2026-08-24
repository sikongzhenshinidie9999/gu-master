import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import 'package:sidequest/src/features/cultivation/data/cultivation_session.dart';
import 'package:sidequest/src/features/cultivation/data/dao.dart';
import 'package:sidequest/src/features/cultivation/data/dao_zhu.dart';
import 'package:sidequest/src/features/cultivation/data/gu_insect.dart';
import 'package:sidequest/src/features/cultivation/data/gu_material.dart';
import 'package:sidequest/src/features/cultivation/data/player_profile.dart';
import 'package:sidequest/src/features/cultivation/data/session_box_provider.dart';
import 'package:sidequest/src/features/cultivation/data/tribulation_record.dart';
import 'package:sidequest/src/features/cultivation/logic/cultivation_provider.dart';
import 'package:sidequest/src/features/cultivation/logic/faction_realm_config.dart';
import 'package:sidequest/src/features/cultivation/logic/gu_power_config.dart';
import 'package:sidequest/src/features/cultivation/logic/tribulation_config.dart';
import 'package:sidequest/src/features/quests/data/quest_model.dart';
import 'package:sidequest/src/features/quests/logic/quest_provider.dart';
import 'package:sidequest/src/features/stats/presentation/screens/legacy_screen.dart';

/// 固定值 Random，用于确定性控制炼蛊结果。
class _FixedRandom implements Random {
  final double doubleValue;
  _FixedRandom(this.doubleValue);

  @override
  double nextDouble() => doubleValue;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => doubleValue < 0.5;
}

/// 九转所需道痕（唯一来源：阶段五配置）。
final int _kNineTurnDaoTraces = kDaoTracesRequiredByTurn[9]!;

/// 无上大宗师所需感悟（唯一来源：流派境界配置）。
final int _kSupremeGrandmasterRealmExp = kFactionRealmExpThresholds.last;

void main() {
  // TypeAdapter 全局只注册一次
  Hive.registerAdapter(QuestModelAdapter());
  Hive.registerAdapter(PlayerProfileAdapter());
  Hive.registerAdapter(TribulationRecordAdapter());
  Hive.registerAdapter(GuInsectAdapter());
  Hive.registerAdapter(GuMaterialAdapter());
  Hive.registerAdapter(DaoZhuStateAdapter());

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

  // Hive 的异步文件 I/O 在 testWidgets 的伪异步下会挂起，必须用 runAsync 包装。
  Future<void> initEnv(WidgetTester tester) async {
    debugPrint('ENV: start');
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(() async {
      // 上一个测试的 Box 仍注册在 Hive 单例中，先关闭再重建，保证测试隔离。
      await Hive.close();
      try {
        await Hive.deleteFromDisk();
      } catch (_) {}
      // testWidgets 的 FakeAsync 下真实文件 I/O 永远不会完成：Notifier 构造 /
      // 任务加载时的 Hive 写入会把内部读写链挂起，导致下一个测试的
      // deleteFromDisk / openBox 死锁。这里统一使用内存后端，写入即时完成。
      tempDir = await Directory.systemTemp.createTemp('legacy_screen_test_');
      Hive.init(tempDir.path);
      cultivationBox = await Hive.openBox<PlayerProfile>(
        'cultivation',
        bytes: Uint8List(0),
      );
      debugPrint('ENV: boxes open');
      questBox = await Hive.openBox<QuestModel>('quests', bytes: Uint8List(0));
      sessionBox = await Hive.openBox<CultivationSession>(
          'sessions',
          bytes: Uint8List(0));
      await Hive.openBox('stats', bytes: Uint8List(0));
      await Hive.openBox('settings', bytes: Uint8List(0));
    });
    container = ProviderContainer(overrides: [
      questBoxProvider.overrideWithValue(questBox),
      cultivationBoxProvider.overrideWithValue(cultivationBox),
      sessionBoxProvider.overrideWithValue(sessionBox),
    ]);
  }

  Future<void> pumpLegacy(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: LegacyScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openRefineDialog(WidgetTester tester) async {
    await tester.ensureVisible(find.text('炼蛊'));
    await tester.pump();
    await tester.tap(find.text('炼蛊'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // 弹窗动画完成
  }

  testWidgets('蛊材为空时显示空状态', (tester) async {
    await initEnv(tester);
    await pumpLegacy(tester);
    expect(find.text('暂无蛊材'), findsOneWidget);
  });

  testWidgets('蛊材正常显示名称与数量', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile();
    profile.guMaterials.add(GuMaterial(materialId: 'bronze_sand', quantity: 3));
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('青铜沙（普通）'), findsOneWidget);
    expect(find.text('×3'), findsOneWidget);
  });

  testWidgets('蛊虫为空时显示空状态', (tester) async {
    await initEnv(tester);
    await pumpLegacy(tester);
    expect(find.text('暂无蛊虫'), findsOneWidget);
  });

  testWidgets('蛊虫正常显示名称/转数/流派/品质', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile();
    profile.guInsects.add(GuInsect(
      id: 'g1',
      turn: 1,
      refinedDaoLevel: 2,
      definitionId: 'bronze_beetle',
      faction: Faction.li.index,
      quality: 0,
    ));
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('青铜甲蛊'), findsOneWidget);
    expect(find.text('普通 · 力道流派 · 1 转 · 炼道 宗师'), findsOneWidget);
  });

  testWidgets('definitionId 无效不会崩溃', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile();
    profile.guInsects.add(GuInsect(
      id: 'g1',
      turn: 1,
      refinedDaoLevel: 0,
      definitionId: 'nope',
      faction: 0,
      quality: 0,
    ));
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('未知蛊虫'), findsOneWidget);
  });

  testWidgets('materialId 无效不会崩溃', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile();
    profile.guMaterials.add(GuMaterial(materialId: 'nope', quantity: 2));
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('未知蛊材（未知品质）'), findsOneWidget);
  });

  testWidgets('材料不足时不能炼', (tester) async {
    await initEnv(tester);
    await pumpLegacy(tester);
    await openRefineDialog(tester);
    final buttons = tester.widgetList<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '炼制'));
    expect(buttons.isNotEmpty, isTrue);
    for (final b in buttons) {
      expect(b.onPressed, isNull);
    }
  });

  testWidgets('材料足够时可以炼', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile();
    profile.guMaterials.add(GuMaterial(materialId: 'bronze_sand', quantity: 3));
    profile.guMaterials.add(GuMaterial(materialId: 'iron_powder', quantity: 1));
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    await openRefineDialog(tester);
    final buttons = tester.widgetList<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '炼制'));
    expect(buttons.any((b) => b.onPressed != null), isTrue);
  });

  testWidgets('炼蛊成功后 UI 能看到新蛊虫，材料正确减少', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile();
    profile.guMaterials.add(GuMaterial(materialId: 'bronze_sand', quantity: 3));
    profile.guMaterials.add(GuMaterial(materialId: 'iron_powder', quantity: 1));
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);

    final notifier = container.read(cultivationProvider.notifier);
    final result = notifier.refineGuInsect(
      insectDefinitionId: 'bronze_beetle',
      random: _FixedRandom(0.0),
    );
    expect(result.success, isTrue);
    await tester.pump();

    expect(find.text('青铜甲蛊'), findsWidgets);
    final after = container.read(cultivationProvider).profile;
    expect(after.guMaterials, isEmpty); // bronze_sand 3 与 iron_powder 1 均已消耗
    expect(after.guInsects.length, 1);
  });

  testWidgets('炼道境界来自 factionRealmExp：普通', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile();
    await tester.runAsync(() => cultivationBox.add(profile)); // factionRealmExp 空 → 炼道普通
    await pumpLegacy(tester);
    await openRefineDialog(tester);
    expect(find.text('炼道境界：普通'), findsOneWidget);
  });

  testWidgets('语义隔离：daoTraces 300000 感悟 0 → 炼道普通', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(daoTraces: {DaoKind.lian.index: 300000});
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    await openRefineDialog(tester);
    expect(find.text('炼道境界：普通'), findsOneWidget);
  });

  testWidgets('语义隔离：daoTraces 0 感悟 100000 → 炼道无上大宗师', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
        factionRealmExp: {Faction.lian.daoKind.index: 100000});
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    await openRefineDialog(tester);
    expect(find.text('炼道境界：无上大宗师'), findsOneWidget);
  });

  // ================= 6D：九转 / 渡劫 UI =================

  testWidgets('名义九转但未真正突破 → 八转巅峰 · 待突破', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(); // nineTurnReached 默认 false
    await tester.runAsync(() => cultivationBox.add(profile));
    await tester.runAsync(() => Hive.box('stats').put('totalXp', 10000));
    await pumpLegacy(tester);
    expect(find.text('八转巅峰 · 待突破'), findsOneWidget);
    expect(find.text('已达名义九转门槛，尚未完成真正突破'), findsOneWidget);
  });

  testWidgets('真正突破九转 → 显示九转蛊尊与突破时间', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      nineTurnReached: true,
      nineTurnBreakthroughAt: DateTime(2026, 8, 24, 12, 0),
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('九转蛊尊'), findsOneWidget);
    expect(find.textContaining('九转突破于'), findsOneWidget);
  });

  testWidgets('九转前置：道痕不足 → 显示不满足', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: 100},
      factionRealmExp: {Faction.li.daoKind.index: _kSupremeGrandmasterRealmExp},
      xianYuan: XianYuanType.baili.index,
      tribulations: [
        TribulationRecord(
            realmLevel: 9, stageIndex: kTribulationCompletedStageIndex),
      ],
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('主修流派：力道流派'), findsOneWidget);
    expect(find.text('道痕：100 / $_kNineTurnDaoTraces ✗'), findsOneWidget);
    expect(find.text('流派境界：无上大宗师 ✓'), findsOneWidget);
    expect(find.text('白荔仙元：已具备'), findsOneWidget);
    expect(find.text('尊者劫：已完成'), findsOneWidget);
    expect(find.text('总体：条件未满足'), findsOneWidget);
  });

  testWidgets('九转前置：境界不足 → 显示不满足', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: _kNineTurnDaoTraces},
      factionRealmExp: {Faction.li.daoKind.index: 100},
      xianYuan: XianYuanType.baili.index,
      tribulations: [
        TribulationRecord(
            realmLevel: 9, stageIndex: kTribulationCompletedStageIndex),
      ],
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('道痕：$_kNineTurnDaoTraces / $_kNineTurnDaoTraces ✓'),
        findsOneWidget);
    expect(find.text('流派境界：普通 ✗'), findsOneWidget);
    expect(find.text('总体：条件未满足'), findsOneWidget);
  });

  testWidgets('九转前置：白荔仙元不足 → 显示不满足', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: _kNineTurnDaoTraces},
      factionRealmExp: {Faction.li.daoKind.index: _kSupremeGrandmasterRealmExp},
      xianYuan: XianYuanType.none.index,
      tribulations: [
        TribulationRecord(
            realmLevel: 9, stageIndex: kTribulationCompletedStageIndex),
      ],
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('白荔仙元：未具备'), findsOneWidget);
    expect(find.text('总体：条件未满足'), findsOneWidget);
  });

  testWidgets('九转前置：尊者劫未完成 → 显示不满足', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: _kNineTurnDaoTraces},
      factionRealmExp: {Faction.li.daoKind.index: _kSupremeGrandmasterRealmExp},
      xianYuan: XianYuanType.baili.index,
      // 无 (9,3) 尊者劫完成记录
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('尊者劫：未完成'), findsOneWidget);
    expect(find.text('总体：条件未满足'), findsOneWidget);
  });

  testWidgets('九转前置：全部满足 → 可突破', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: _kNineTurnDaoTraces},
      factionRealmExp: {Faction.li.daoKind.index: _kSupremeGrandmasterRealmExp},
      xianYuan: XianYuanType.baili.index,
      tribulations: [
        TribulationRecord(
            realmLevel: 9, stageIndex: kTribulationCompletedStageIndex),
      ],
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('道痕：$_kNineTurnDaoTraces / $_kNineTurnDaoTraces ✓'),
        findsOneWidget);
    expect(find.text('流派境界：无上大宗师 ✓'), findsOneWidget);
    expect(find.text('白荔仙元：已具备'), findsOneWidget);
    expect(find.text('尊者劫：已完成'), findsOneWidget);
    expect(find.text('总体：条件已满足，可突破'), findsOneWidget);
  });

  testWidgets('主修流派展示（按感悟派生）', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      factionRealmExp: {
        Faction.zhi.daoKind.index: 500,
        Faction.li.daoKind.index: 100,
      },
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('主修流派：智道流派'), findsOneWidget);
  });

  testWidgets('渡劫卡：到期/未到/已完成 展示与距离/渡过次数', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      currentCultivation: 11333, // 越过六/七/八转全部里程碑
      tribulations: [
        TribulationRecord(realmLevel: 6, stageIndex: 0),
        TribulationRecord(realmLevel: 7, stageIndex: 1),
        TribulationRecord(realmLevel: 8, stageIndex: 2),
        TribulationRecord(
            realmLevel: 9, stageIndex: kTribulationCompletedStageIndex),
      ],
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('六转'), findsOneWidget);
    expect(find.text('劫难已至 · 1/3'), findsOneWidget);
    expect(find.text('劫难已至 · 2/3'), findsOneWidget);
    expect(find.text('劫难已至 · 3/3'), findsOneWidget);
    expect(find.text('九转尊者劫'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('已度过劫难：6 次'), findsOneWidget);
  });

  testWidgets('渡劫未到/已完成展示（当前修为低）', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(currentCultivation: 0);
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('未到劫难'), findsNWidgets(4)); // 六/七/八/九转
    expect(find.text('距下一劫难：还差 2833 修为'), findsOneWidget);
    expect(find.text('已度过劫难：0 次'), findsOneWidget);
  });

  testWidgets('冷却状态与失败次数展示', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      currentCultivation: 3000, // 达六转 1/3 里程碑 → 劫难已至
      tribulations: [
        TribulationRecord(
          realmLevel: 6,
          stageIndex: 0,
          failCount: 1,
          lastAttemptAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ],
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('劫难已至 · 1/3'), findsOneWidget);
    expect(find.textContaining('失败 1 次'), findsOneWidget);
    expect(find.textContaining('冷却中'), findsWidgets);
  });

  testWidgets('渡劫按钮产生成功/失败反馈', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(currentCultivation: 3000); // 六转到期
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, '渡劫').first);
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, '渡劫').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byWidgetPredicate((w) =>
          w is Text &&
          (w.data?.contains('渡劫成功') == true ||
              w.data?.contains('渡劫失败') == true)),
      findsWidgets,
    );
  });

  testWidgets('冷却中点击渡劫 → 渡劫冷却中', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      currentCultivation: 3000, // 六转到期
      tribulations: [
        TribulationRecord(
          realmLevel: 6,
          stageIndex: 0,
          lastAttemptAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ],
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, '渡劫').first);
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, '渡劫').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('渡劫冷却中'), findsOneWidget);
  });

  testWidgets('九转突破成功 SnackBar', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: _kNineTurnDaoTraces},
      factionRealmExp: {Faction.li.daoKind.index: _kSupremeGrandmasterRealmExp},
      xianYuan: XianYuanType.baili.index,
      tribulations: [
        TribulationRecord(
            realmLevel: 9, stageIndex: kTribulationCompletedStageIndex),
      ],
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    await tester.ensureVisible(find.text('尝试突破'));
    await tester.pump();
    await tester.tap(find.text('尝试突破'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('九转突破成功 · 白荔仙元已质变为黄杏仙元'), findsOneWidget);
  });

  testWidgets('九转突破失败原因 SnackBar', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: 100}, // 道痕不足
      factionRealmExp: {Faction.li.daoKind.index: _kSupremeGrandmasterRealmExp},
      xianYuan: XianYuanType.baili.index,
      tribulations: [
        TribulationRecord(
            realmLevel: 9, stageIndex: kTribulationCompletedStageIndex),
      ],
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    await tester.ensureVisible(find.text('尝试突破'));
    await tester.pump();
    await tester.tap(find.text('尝试突破'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('九转突破失败：主修流派道痕不足'), findsOneWidget);
  });

  testWidgets('已突破九转 → 尝试突破按钮禁用', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      nineTurnReached: true,
      nineTurnBreakthroughAt: DateTime(2026, 8, 24, 12, 0),
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '尝试突破'));
    expect(button.onPressed, isNull);
  });

  testWidgets('语义隔离：高道痕+低境界 → 境界不满足', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: _kNineTurnDaoTraces},
      factionRealmExp: {Faction.li.daoKind.index: 100},
      xianYuan: XianYuanType.baili.index,
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('道痕：$_kNineTurnDaoTraces / $_kNineTurnDaoTraces ✓'),
        findsOneWidget);
    expect(find.text('流派境界：普通 ✗'), findsOneWidget);
  });

  testWidgets('语义隔离：低道痕+高境界 → 道痕不满足', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: 100},
      factionRealmExp: {Faction.li.daoKind.index: _kSupremeGrandmasterRealmExp},
      xianYuan: XianYuanType.baili.index,
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('道痕：100 / $_kNineTurnDaoTraces ✗'), findsOneWidget);
    expect(find.text('流派境界：无上大宗师 ✓'), findsOneWidget);
  });

  testWidgets('九转突破后页面自动重建显示九转蛊尊（无需重新 pump）', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: _kNineTurnDaoTraces},
      factionRealmExp: {Faction.li.daoKind.index: _kSupremeGrandmasterRealmExp},
      xianYuan: XianYuanType.baili.index,
      tribulations: [
        TribulationRecord(
            realmLevel: 9, stageIndex: kTribulationCompletedStageIndex),
      ],
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await tester.runAsync(() => Hive.box('stats').put('totalXp', 10000));
    await pumpLegacy(tester);
    // 初始 Provider state：nineTurnReached == false → 名义九转显示「八转巅峰 · 待突破」
    expect(find.text('八转巅峰 · 待突破'), findsOneWidget);

    // 通过现有 UI 点击九转突破按钮（条件全部满足）
    await tester.ensureVisible(find.text('尝试突破'));
    await tester.pump();
    await tester.tap(find.text('尝试突破'));
    await tester.pump(); // 等待 Provider state 更新触发自动 rebuild
    await tester.pump(const Duration(milliseconds: 200));

    // 不重新 pump LegacyScreen，仅靠 ref.watch(cultivationProvider) 自动重建
    expect(find.text('九转蛊尊'), findsOneWidget);
    expect(find.text('八转巅峰 · 待突破'), findsNothing);
  });

  // ================= 6E-3：道主 UI =================

  testWidgets('未成为道主时显示道主资格卡', (tester) async {
    await initEnv(tester);
    await tester.runAsync(() => cultivationBox.add(PlayerProfile()));
    await pumpLegacy(tester);
    expect(find.text('尝试授予道主'), findsOneWidget);
    expect(find.text('总体资格：✗'), findsOneWidget);
  });

  testWidgets('九转不足显示 ✗', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: _kNineTurnDaoTraces},
      factionRealmExp: {Faction.li.daoKind.index: _kSupremeGrandmasterRealmExp},
      nineTurnReached: false,
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('九转：✗'), findsOneWidget);
  });

  testWidgets('流派境界不足显示 ✗', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: _kNineTurnDaoTraces},
      factionRealmExp: {Faction.li.daoKind.index: 100},
      nineTurnReached: true,
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('流派境界：✗'), findsOneWidget);
  });

  testWidgets('道痕不足显示 ✗', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: 100},
      factionRealmExp: {Faction.li.daoKind.index: _kSupremeGrandmasterRealmExp},
      nineTurnReached: true,
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('道痕：✗'), findsOneWidget);
  });

  testWidgets('当世理解最深默认显示 ✗', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: _kNineTurnDaoTraces},
      factionRealmExp: {Faction.li.daoKind.index: _kSupremeGrandmasterRealmExp},
      nineTurnReached: true,
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('当世理解最深：✗'), findsOneWidget);
  });

  testWidgets('可评估资格全部满足：九转/境界/道痕 ✓，理解最深 ✗（无真实来源）', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: _kNineTurnDaoTraces},
      factionRealmExp: {Faction.li.daoKind.index: _kSupremeGrandmasterRealmExp},
      nineTurnReached: true,
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('九转：✓'), findsOneWidget);
    expect(find.text('流派境界：✓'), findsOneWidget);
    expect(find.text('道痕：✓'), findsOneWidget);
    expect(find.text('当世理解最深：✗'), findsOneWidget);
    expect(find.text('总体资格：✗'), findsOneWidget);
  });

  testWidgets('已有 daoZhu 时显示道主身份', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoZhu: DaoZhuState(
        faction: Faction.li.index,
        crownedAt: DateTime(2026, 8, 24, 12, 0),
        eraId: 'era-1',
      ),
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('状态：已授予'), findsOneWidget);
    expect(find.text('道主流派：力道流派'), findsOneWidget);
    expect(find.text('授予时间：2026-08-24 12:00'), findsOneWidget);
    expect(find.text('时代：era-1'), findsOneWidget);
    expect(find.text('尝试授予道主'), findsNothing);
  });

  testWidgets('eraId 为空时不显示时代行', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoZhu: DaoZhuState(
        faction: Faction.zhi.index,
        crownedAt: DateTime(2026, 8, 24, 12, 0),
        eraId: '',
      ),
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('道主流派：智道流派'), findsOneWidget);
    expect(find.textContaining('时代'), findsNothing);
  });

  testWidgets('没有主修流派时按钮不可授予', (tester) async {
    await initEnv(tester);
    await tester.runAsync(() => cultivationBox.add(PlayerProfile()));
    await pumpLegacy(tester);
    expect(find.text('授予流派：尚未确定主修流派'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '尝试授予道主'));
    expect(button.onPressed, isNull);
  });

  testWidgets('点击授予且 deepest=false → 显示失败原因', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: _kNineTurnDaoTraces},
      factionRealmExp: {Faction.li.daoKind.index: _kSupremeGrandmasterRealmExp},
      nineTurnReached: true,
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    await tester.ensureVisible(find.text('尝试授予道主'));
    await tester.pump();
    await tester.tap(find.text('尝试授予道主'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('道主授予失败：当世理解最深未满足'), findsOneWidget);
  });

  testWidgets('已经是道主时无授予入口', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoZhu: DaoZhuState(
        faction: Faction.li.index,
        crownedAt: DateTime(2026, 8, 24),
        eraId: 'era-1',
      ),
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('状态：已授予'), findsOneWidget);
    expect(find.text('尝试授予道主'), findsNothing);
  });

  testWidgets('道主授予成功后 UI 自动 rebuild（无需重新 pump）', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: _kNineTurnDaoTraces},
      factionRealmExp: {Faction.li.daoKind.index: _kSupremeGrandmasterRealmExp},
      nineTurnReached: true,
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('总体资格：✗'), findsOneWidget);

    // 通过 Provider 真实 API 走成功路径（UI 无真实 deepest 来源，测试不虚构业务事实）
    final notifier = container.read(cultivationProvider.notifier);
    final result = notifier.grantDaoZhu(
      faction: Faction.li,
      isDeepestUnderstanding: true,
      eraId: 'era-1',
      now: DateTime(2026, 8, 24, 12, 0),
    );
    expect(result.success, isTrue);
    await tester.pump();

    // 不重新 pump LegacyScreen，仅靠 ref.watch(cultivationProvider) 自动重建
    expect(find.text('状态：已授予'), findsOneWidget);
    expect(find.text('道主流派：力道流派'), findsOneWidget);
    expect(find.text('总体资格：✗'), findsNothing);
  });

  testWidgets('九转蛊尊不会因九转突破自动显示道主', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      nineTurnReached: true,
      nineTurnBreakthroughAt: DateTime(2026, 8, 24, 12, 0),
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('九转蛊尊'), findsOneWidget); // 名义展示为真实九转
    expect(find.text('尝试授予道主'), findsOneWidget); // 仍是资格卡
    expect(find.text('状态：已授予'), findsNothing); // 未自动成为道主
  });

  testWidgets('高道痕+无上大宗师+九转，但 deepest=false → 仍不能授予', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: _kNineTurnDaoTraces},
      factionRealmExp: {Faction.li.daoKind.index: _kSupremeGrandmasterRealmExp},
      nineTurnReached: true,
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    expect(find.text('九转：✓'), findsOneWidget);
    expect(find.text('流派境界：✓'), findsOneWidget);
    expect(find.text('道痕：✓'), findsOneWidget);
    expect(find.text('当世理解最深：✗'), findsOneWidget);
    expect(find.text('总体资格：✗'), findsOneWidget);
    await tester.ensureVisible(find.text('尝试授予道主'));
    await tester.pump();
    await tester.tap(find.text('尝试授予道主'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('道主授予失败：当世理解最深未满足'), findsOneWidget);
  });

  testWidgets('UI 不复制资格公式：高道痕+低境界显示混合结果', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
      daoTraces: {DaoKind.li.index: _kNineTurnDaoTraces},
      factionRealmExp: {Faction.li.daoKind.index: 100},
      nineTurnReached: true,
    );
    await tester.runAsync(() => cultivationBox.add(profile));
    await pumpLegacy(tester);
    // UI 只消费 getter：道痕满足、境界不满足，二者独立显示
    expect(find.text('道痕：✓'), findsOneWidget);
    expect(find.text('流派境界：✗'), findsOneWidget);
    expect(find.text('总体资格：✗'), findsOneWidget);
  });

  testWidgets('显示学习成长卡（今日/累计/连续）', (tester) async {
    await initEnv(tester);
    // 种子：今日 45 分钟完成 + 连续 3 天
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 8);
    final session = CultivationSession(
      id: 's1',
      startTime: today,
      endTime: today.add(const Duration(minutes: 45)),
      plannedDurationMinutes: 45,
      actualDurationMinutes: 45,
      subject: '英语',
      category: CultivationSessionCategory.shen.index,
      status: CultivationSessionStatus.completed.index,
      xpEarned: 90,
      daoTraceKind: 2,
      daoTraceAmount: 45,
      realmExpEarned: 45,
    );
    await tester.runAsync(() => sessionBox.add(session));
    await tester.runAsync(() => Hive.box('stats').put('studyStreak', 3));

    await pumpLegacy(tester);
    expect(find.text('学习修炼'), findsOneWidget);
    expect(find.text('今日闭关：45 分钟'), findsOneWidget);
    // 「本周闭关」在学习修炼卡与近期修炼回顾卡各出现一次
    expect(find.text('本周闭关：45 分钟'), findsNWidgets(2));
    expect(find.text('累计闭关：45 分钟'), findsOneWidget);
    expect(find.text('连续修炼：3 天'), findsOneWidget);
    expect(find.text('完成次数：1 次'), findsOneWidget);
    // B-4/5/6 新增卡片存在
    expect(find.text('近期修炼回顾'), findsOneWidget);
    expect(find.text('修炼成就'), findsOneWidget);
    expect(find.text('我的纪录'), findsOneWidget);
  });
}
