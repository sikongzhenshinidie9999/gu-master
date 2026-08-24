import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
import 'package:sidequest/src/features/cultivation/logic/nine_turn_prerequisites.dart';
import 'package:sidequest/src/features/quests/data/quest_model.dart';

/// 九转所需道痕（唯一来源：阶段五配置，不复制魔数）。
final int _kNineTurnDaoTraces = kDaoTracesRequiredByTurn[9]!;

/// 无上大宗师所需感悟（唯一来源：流派境界配置）。
final int _kSupremeGrandmasterRealmExp = kFactionRealmExpThresholds.last;

/// 设置玩家档案到「基本满足」状态（可逐项覆盖）。
void _setupProfile(
  CultivationNotifier cult, {
  Faction primary = Faction.li,
  int? primaryFaction,
  int? traces,
  int? realmExp,
  int? xianYuan,
  bool nineTurnReached = false,
  int? totalXp,
}) {
  final p = cult.state.profile;
  if (traces != null) p.daoTraces[primary.daoKind.index] = traces;
  if (realmExp != null) p.factionRealmExp[primary.daoKind.index] = realmExp;
  p.xianYuan = xianYuan ?? XianYuanType.baili.index;
  if (primaryFaction != null) p.primaryFaction = primaryFaction;
  p.nineTurnReached = nineTurnReached;
  if (totalXp != null) p.totalXp = totalXp;
}

void main() {
  // TypeAdapter 全局只注册一次
  Hive.registerAdapter(QuestModelAdapter()); // typeId 0
  Hive.registerAdapter(PlayerProfileAdapter()); // typeId 1
  Hive.registerAdapter(TribulationRecordAdapter()); // typeId 2
  Hive.registerAdapter(GuInsectAdapter()); // typeId 3
  Hive.registerAdapter(GuMaterialAdapter()); // typeId 4
  Hive.registerAdapter(DaoZhuStateAdapter()); // typeId 5

  late Directory tempDir;
  late Box<PlayerProfile> cultivationBox;
  late Box statsBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nine_turn_bt_test_');
    Hive.init(tempDir.path);
    cultivationBox = await Hive.openBox<PlayerProfile>('cultivation');
    await Hive.openBox<QuestModel>('quests');
    statsBox = await Hive.openBox('stats');
    await Hive.openBox('settings');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('PlayerProfile 九转字段 Hive 序列化', () {
    test('新字段写入后读回完全一致', () async {
      final profile = PlayerProfile(
        primaryFaction: Faction.zhi.index,
        nineTurnReached: true,
        nineTurnBreakthroughAt: DateTime(2026, 8, 24, 12, 30),
        daoTraces: {DaoKind.li.index: 123},
        factionRealmExp: {Faction.li.daoKind.index: 456},
      );
      await cultivationBox.add(profile);
      final stored = cultivationBox.values.first;
      expect(stored.primaryFaction, Faction.zhi.index);
      expect(stored.nineTurnReached, isTrue);
      expect(stored.nineTurnBreakthroughAt, DateTime(2026, 8, 24, 12, 30));
    });

    test('旧式构造（未传新参数）默认语义：null / false / null', () async {
      // 模拟旧版档案：只构造旧字段，不带 field 10/11/12
      final profile = PlayerProfile(
        totalXp: 100,
        currentCultivation: 80,
        daoTraces: {DaoKind.li.index: 50},
      );
      await cultivationBox.add(profile);
      final stored = cultivationBox.values.first;
      expect(stored.primaryFaction, isNull);
      expect(stored.nineTurnReached, isFalse);
      expect(stored.nineTurnBreakthroughAt, isNull);
      // 旧字段不受影响
      expect(stored.totalXp, 100);
      expect(stored.daoTraces[DaoKind.li.index], 50);
    });
  });

  group('attemptNineTurnBreakthrough Provider', () {
    test('四条件全部满足 → 成功：nineTurnReached、时间戳、白荔→黄杏', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces, realmExp: _kSupremeGrandmasterRealmExp);

      final result = cult.attemptNineTurnBreakthrough(tribulationSatisfied: true);

      expect(result.success, isTrue);
      expect(result.status, NineTurnBreakthroughStatus.succeeded);
      expect(result.failureReason, isNull);
      expect(cult.state.profile.nineTurnReached, isTrue);
      expect(cult.state.profile.nineTurnBreakthroughAt, isNotNull);
      expect(cult.state.profile.xianYuan, XianYuanType.huangxing.index);
      expect(result.nineTurnBreakthroughAt, isNotNull);
      expect(result.xianYuanAfter, XianYuanType.huangxing.index);
    });

    test('道痕不足 → 失败，状态不变，仙元不变', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces - 1, realmExp: _kSupremeGrandmasterRealmExp);

      final result = cult.attemptNineTurnBreakthrough(tribulationSatisfied: true);

      expect(result.success, isFalse);
      expect(result.status, NineTurnBreakthroughStatus.failed);
      expect(result.failureReason, '主修流派道痕不足');
      expect(cult.state.profile.nineTurnReached, isFalse);
      expect(cult.state.profile.nineTurnBreakthroughAt, isNull);
      expect(cult.state.profile.xianYuan, XianYuanType.baili.index);
    });

    test('境界不足 → 失败，状态不变', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces, realmExp: _kSupremeGrandmasterRealmExp - 1);

      final result = cult.attemptNineTurnBreakthrough(tribulationSatisfied: true);

      expect(result.success, isFalse);
      expect(result.failureReason, '主修流派境界未达无上大宗师');
      expect(cult.state.profile.nineTurnReached, isFalse);
      expect(cult.state.profile.xianYuan, XianYuanType.baili.index);
    });

    test('仙元错误 → 失败，状态不变', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
          xianYuan: XianYuanType.none.index);

      final result = cult.attemptNineTurnBreakthrough(tribulationSatisfied: true);

      expect(result.success, isFalse);
      expect(result.failureReason, '仙元不是白荔仙元');
      expect(cult.state.profile.nineTurnReached, isFalse);
      expect(cult.state.profile.xianYuan, XianYuanType.none.index);
    });

    test('渡劫未完成 → 失败，状态不变', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces, realmExp: _kSupremeGrandmasterRealmExp);

      final result = cult.attemptNineTurnBreakthrough(tribulationSatisfied: false);

      expect(result.success, isFalse);
      expect(result.failureReason, '未完成尊者级渡劫');
      expect(cult.state.profile.nineTurnReached, isFalse);
      expect(cult.state.profile.xianYuan, XianYuanType.baili.index);
    });

    test('已经突破 → alreadyReached，时间戳不变，仙元不重复质变', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
          nineTurnReached: true);
      final ts = DateTime(2026, 8, 24, 8, 0);
      cult.state.profile.nineTurnBreakthroughAt = ts;
      cult.state.profile.xianYuan = XianYuanType.huangxing.index;

      final result = cult.attemptNineTurnBreakthrough(tribulationSatisfied: true);

      expect(result.success, isFalse);
      expect(result.status, NineTurnBreakthroughStatus.alreadyReached);
      expect(result.failureReason, '已突破九转');
      expect(cult.state.profile.nineTurnBreakthroughAt, ts); // 时间戳不变化
      expect(cult.state.profile.xianYuan, XianYuanType.huangxing.index);
    });

    test('四条件独立性回归：分别只关闭一个条件均失败', () {
      final cases = <String, void Function(CultivationNotifier)>{
        '道痕': (c) => _setupProfile(c,
            traces: _kNineTurnDaoTraces - 1, realmExp: _kSupremeGrandmasterRealmExp),
        '境界': (c) => _setupProfile(c,
            traces: _kNineTurnDaoTraces, realmExp: _kSupremeGrandmasterRealmExp - 1),
        '仙元': (c) => _setupProfile(c,
            traces: _kNineTurnDaoTraces,
            realmExp: _kSupremeGrandmasterRealmExp,
            xianYuan: XianYuanType.none.index),
        '渡劫': (c) => _setupProfile(c,
            traces: _kNineTurnDaoTraces, realmExp: _kSupremeGrandmasterRealmExp),
      };
      cases.forEach((name, setup) {
        final cult = CultivationNotifier(cultivationBox, statsBox);
        setup(cult);
        final tribulationSatisfied = name != '渡劫';
        final result =
            cult.attemptNineTurnBreakthrough(tribulationSatisfied: tribulationSatisfied);
        expect(result.success, isFalse, reason: '$name 条件单独关闭时应失败');
        expect(cult.state.profile.nineTurnReached, isFalse);
      });
    });

    test('primaryFaction：有合法值时优先使用，不再按感悟派生', () {
      // 显式 primaryFaction = 智道；力道感悟极高但智道不足 → 走智道判断
      final cult = CultivationNotifier(cultivationBox, statsBox);
      cult.state.profile.primaryFaction = Faction.zhi.index;
      cult.state.profile.daoTraces[Faction.li.daoKind.index] = _kNineTurnDaoTraces;
      cult.state.profile.factionRealmExp[Faction.li.daoKind.index] =
          _kSupremeGrandmasterRealmExp;
      // 智道：道痕/感悟均为 0 → 不足
      final result = cult.attemptNineTurnBreakthrough(tribulationSatisfied: true);
      expect(result.success, isFalse);
      expect(result.failureReason, '主修流派道痕不足');
      expect(resolvePrimaryFaction(cult.state.profile), Faction.zhi);
    });

    test('primaryFaction：无显式值时仍按 6A 派生', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      cult.state.profile.factionRealmExp[Faction.lian.daoKind.index] = 99999;
      expect(resolvePrimaryFaction(cult.state.profile), Faction.lian);
      // 全部条件满足（主修为炼道）
      cult.state.profile.daoTraces[Faction.lian.daoKind.index] = _kNineTurnDaoTraces;
      cult.state.profile.factionRealmExp[Faction.lian.daoKind.index] =
          _kSupremeGrandmasterRealmExp;
      cult.state.profile.xianYuan = XianYuanType.baili.index;
      final result = cult.attemptNineTurnBreakthrough(tribulationSatisfied: true);
      expect(result.success, isTrue);
    });

    test('primaryFaction：非法值安全回退派生，不崩溃', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      cult.state.profile.primaryFaction = 99;
      cult.state.profile.factionRealmExp[Faction.zhi.daoKind.index] = 500;
      expect(resolvePrimaryFaction(cult.state.profile), Faction.zhi);
      // 条件不足 → 失败而非崩溃
      final result = cult.attemptNineTurnBreakthrough(tribulationSatisfied: true);
      expect(result.success, isFalse);
    });

    test('持久化：成功突破后重新读取状态仍然存在', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces, realmExp: _kSupremeGrandmasterRealmExp);
      final result = cult.attemptNineTurnBreakthrough(tribulationSatisfied: true);
      expect(result.success, isTrue);

      // 模拟重启后重新读取
      final second = CultivationNotifier(cultivationBox, statsBox);
      expect(second.state.profile.nineTurnReached, isTrue);
      expect(second.state.profile.nineTurnBreakthroughAt, isNotNull);
      expect(second.state.profile.xianYuan, XianYuanType.huangxing.index);
    });

    test('语义隔离：realm totalXp 不能直接产生 nineTurnReached', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      // 修为远超 10000，但其他条件全无
      _setupProfile(cult, totalXp: 999999);
      final result = cult.attemptNineTurnBreakthrough(tribulationSatisfied: true);
      expect(result.success, isFalse);
      expect(cult.state.profile.nineTurnReached, isFalse);
    });

    test('语义隔离：daoTraces 与 factionRealmExp 互不影响', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final p = cult.state.profile;
      p.daoTraces[DaoKind.li.index] = 300000;
      p.factionRealmExp[Faction.li.daoKind.index] = 100;
      final daoBefore = p.daoTraces[DaoKind.li.index];
      final expBefore = p.factionRealmExp[Faction.li.daoKind.index];

      // 修改感悟 → 道痕不变
      p.factionRealmExp[Faction.li.daoKind.index] = 5000;
      expect(p.daoTraces[DaoKind.li.index], daoBefore);
      // 修改道痕 → 感悟不变
      p.daoTraces[DaoKind.li.index] = 1;
      expect(p.factionRealmExp[Faction.li.daoKind.index], 5000);
      // 道痕变化不影响之前的感悟快照值
      expect(p.daoTraces[DaoKind.li.index], 1);
      expect(expBefore, 100);
    });
  });
}
