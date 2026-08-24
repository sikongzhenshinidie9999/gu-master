import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import 'package:sidequest/src/features/cultivation/data/dao.dart';
import 'package:sidequest/src/features/cultivation/data/dao_zhu.dart';
import 'package:sidequest/src/features/cultivation/data/gu_insect.dart';
import 'package:sidequest/src/features/cultivation/data/gu_material.dart';
import 'package:sidequest/src/features/cultivation/data/player_profile.dart';
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
      await Hive.openBox('stats', bytes: Uint8List(0));
      await Hive.openBox('settings', bytes: Uint8List(0));
    });
    container = ProviderContainer(overrides: [
      questBoxProvider.overrideWithValue(questBox),
      cultivationBoxProvider.overrideWithValue(cultivationBox),
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

  testWidgets('渡劫 stage 展示：1/3、2/3、3/3、九转已完成', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
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
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('3/3'), findsOneWidget);
    expect(find.text('九转尊者劫'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
  });

  testWidgets('渡劫未开始/未完成展示', (tester) async {
    await initEnv(tester);
    await tester.runAsync(() => cultivationBox.add(PlayerProfile()));
    await pumpLegacy(tester);
    expect(find.text('未开始'), findsNWidgets(3)); // 六/七/八转
    expect(find.text('未完成'), findsOneWidget); // 九转尊者劫
  });

  testWidgets('冷却状态与失败次数展示', (tester) async {
    await initEnv(tester);
    final profile = PlayerProfile(
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
    expect(find.textContaining('失败 1 次'), findsOneWidget);
    expect(find.textContaining('冷却中'), findsWidgets);
  });

  testWidgets('渡劫按钮产生成功/失败反馈', (tester) async {
    await initEnv(tester);
    await tester.runAsync(() => cultivationBox.add(PlayerProfile()));
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
}
