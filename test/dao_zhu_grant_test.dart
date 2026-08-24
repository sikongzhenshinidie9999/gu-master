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
import 'package:sidequest/src/features/cultivation/logic/dao_zhu_service.dart';
import 'package:sidequest/src/features/cultivation/logic/faction_realm_config.dart';
import 'package:sidequest/src/features/cultivation/logic/gu_power_config.dart';
import 'package:sidequest/src/features/quests/data/quest_model.dart';

/// 九转所需道痕（唯一来源：阶段五配置，不复制魔数）。
final int _kNineTurnDaoTraces = kDaoTracesRequiredByTurn[9]!;

/// 无上大宗师所需感悟（唯一来源：流派境界配置）。
final int _kSupremeGrandmasterRealmExp = kFactionRealmExpThresholds.last;

void _setupProfile(
  CultivationNotifier cult, {
  bool nineTurnReached = true,
  Faction faction = Faction.li,
  int? traces,
  int? realmExp,
  int? xianYuan,
  DaoZhuState? daoZhu,
}) {
  final p = cult.state.profile;
  if (traces != null) p.daoTraces[faction.daoKind.index] = traces;
  if (realmExp != null) p.factionRealmExp[faction.daoKind.index] = realmExp;
  p.nineTurnReached = nineTurnReached;
  p.xianYuan = xianYuan ?? XianYuanType.baili.index;
  p.daoZhu = daoZhu;
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
    tempDir = await Directory.systemTemp.createTemp('dao_zhu_grant_test_');
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

  group('grantDaoZhu Provider', () {
    test('全部条件满足 → succeeded 且 daoZhu 正确写入', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces, realmExp: _kSupremeGrandmasterRealmExp);

      final r = cult.grantDaoZhu(
        faction: Faction.li,
        isDeepestUnderstanding: true,
        eraId: 'era-1',
        now: DateTime(2026, 8, 24, 12, 0),
      );

      expect(r.success, isTrue);
      expect(r.status, DaoZhuGrantStatus.succeeded);
      expect(r.failureReason, isNull);
      expect(r.daoZhu, isNotNull);
      expect(r.crownedAt, DateTime(2026, 8, 24, 12, 0));

      final daoZhu = cult.state.profile.daoZhu!;
      expect(daoZhu.faction, Faction.li.index);
      expect(daoZhu.crownedAt, DateTime(2026, 8, 24, 12, 0));
      expect(daoZhu.eraId, 'era-1');
    });

    test('saveProfile 后重新读取 daoZhu 仍存在', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces, realmExp: _kSupremeGrandmasterRealmExp);
      cult.grantDaoZhu(
        faction: Faction.li,
        isDeepestUnderstanding: true,
        eraId: 'era-1',
        now: DateTime(2026, 8, 24),
      );

      final second = CultivationNotifier(cultivationBox, statsBox);
      expect(second.state.profile.daoZhu, isNotNull);
      expect(second.state.profile.daoZhu!.eraId, 'era-1');
      expect(second.state.profile.daoZhu!.faction, Faction.li.index);
    });

    test('九转不足 → failed', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          nineTurnReached: false,
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp);
      final r =
          cult.grantDaoZhu(faction: Faction.li, isDeepestUnderstanding: true);
      expect(r.status, DaoZhuGrantStatus.failed);
      expect(r.failureReason, '尚未突破九转');
    });

    test('流派境界不足 → failed', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp - 1);
      final r =
          cult.grantDaoZhu(faction: Faction.li, isDeepestUnderstanding: true);
      expect(r.status, DaoZhuGrantStatus.failed);
      expect(r.failureReason, '该流派境界未达无上大宗师');
    });

    test('道痕不足 → failed', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces - 1,
          realmExp: _kSupremeGrandmasterRealmExp);
      final r =
          cult.grantDaoZhu(faction: Faction.li, isDeepestUnderstanding: true);
      expect(r.status, DaoZhuGrantStatus.failed);
      expect(r.failureReason, '该流派道痕未达九转要求');
    });

    test('deepestUnderstanding=false → failed', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces, realmExp: _kSupremeGrandmasterRealmExp);
      final r = cult.grantDaoZhu(
          faction: Faction.li, isDeepestUnderstanding: false);
      expect(r.status, DaoZhuGrantStatus.failed);
      expect(r.failureReason, '当世理解最深未满足');
    });

    test('已经存在 daoZhu → alreadyGranted', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(
        cult,
        traces: _kNineTurnDaoTraces,
        realmExp: _kSupremeGrandmasterRealmExp,
        daoZhu: DaoZhuState(
          faction: Faction.zhi.index,
          crownedAt: DateTime(2026, 1, 1),
          eraId: 'era-old',
        ),
      );
      final r =
          cult.grantDaoZhu(faction: Faction.li, isDeepestUnderstanding: true);
      expect(r.status, DaoZhuGrantStatus.alreadyGranted);
      expect(r.failureReason, '已成为道主');
    });

    test('已存在 daoZhu 时不同 faction/eraId/now 也绝不覆盖', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final original = DaoZhuState(
        faction: Faction.zhi.index,
        crownedAt: DateTime(2026, 1, 1),
        eraId: 'era-old',
      );
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
          daoZhu: original);
      final r = cult.grantDaoZhu(
        faction: Faction.li,
        isDeepestUnderstanding: true,
        eraId: 'era-new',
        now: DateTime(2026, 8, 24),
      );
      expect(r.status, DaoZhuGrantStatus.alreadyGranted);
      final after = cult.state.profile.daoZhu!;
      expect(after.faction, Faction.zhi.index);
      expect(after.crownedAt, DateTime(2026, 1, 1));
      expect(after.eraId, 'era-old');
    });

    test('失败不写 Hive（daoZhu 保持 null）', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: 100, realmExp: _kSupremeGrandmasterRealmExp); // 道痕不足
      final r =
          cult.grantDaoZhu(faction: Faction.li, isDeepestUnderstanding: true);
      expect(r.status, DaoZhuGrantStatus.failed);
      expect(cult.state.profile.daoZhu, isNull);

      final second = CultivationNotifier(cultivationBox, statsBox);
      expect(second.state.profile.daoZhu, isNull);
    });

    test('成功不修改其他 profile 字段', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
          xianYuan: XianYuanType.baili.index);
      final p = cult.state.profile;
      p.totalXp = 12345;
      p.currentCultivation = 9999;
      p.guMaterials.add(GuMaterial(materialId: 'bronze_sand', quantity: 2));
      final daoBefore = Map.of(p.daoTraces);
      final expBefore = Map.of(p.factionRealmExp);

      final r = cult.grantDaoZhu(
          faction: Faction.li,
          isDeepestUnderstanding: true,
          now: DateTime(2026, 8, 24));
      expect(r.success, isTrue);

      expect(p.nineTurnReached, isTrue); // 不变
      expect(p.xianYuan, XianYuanType.baili.index); // 不变
      expect(p.daoTraces, daoBefore);
      expect(p.factionRealmExp, expBefore);
      expect(p.totalXp, 12345);
      expect(p.currentCultivation, 9999);
      expect(p.tribulations, isEmpty);
      expect(p.guInsects, isEmpty);
      expect(p.guMaterials.length, 1);
      expect(p.daoZhu, isNotNull); // 唯一新增
    });

    test('now 显式传入时 crownedAt 使用传入时间', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces, realmExp: _kSupremeGrandmasterRealmExp);
      final r = cult.grantDaoZhu(
        faction: Faction.li,
        isDeepestUnderstanding: true,
        now: DateTime(2026, 8, 24, 8, 30),
      );
      expect(r.crownedAt, DateTime(2026, 8, 24, 8, 30));
      expect(cult.state.profile.daoZhu!.crownedAt, DateTime(2026, 8, 24, 8, 30));
    });

    test('eraId 显式传入时正确保存', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces, realmExp: _kSupremeGrandmasterRealmExp);
      cult.grantDaoZhu(
        faction: Faction.li,
        isDeepestUnderstanding: true,
        eraId: 'era-zhou',
        now: DateTime(2026, 8, 24),
      );
      expect(cult.state.profile.daoZhu!.eraId, 'era-zhou');
    });

    test('不传 now 时 crownedAt 使用当前时间', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces, realmExp: _kSupremeGrandmasterRealmExp);
      final before = DateTime.now();
      final r =
          cult.grantDaoZhu(faction: Faction.li, isDeepestUnderstanding: true);
      final after = DateTime.now();
      expect(r.success, isTrue);
      final crowned = cult.state.profile.daoZhu!.crownedAt;
      expect(crowned.isBefore(after) || crowned.isAtSameMomentAs(after), isTrue);
      expect(
          crowned.isAfter(before) || crowned.isAtSameMomentAs(before), isTrue);
    });

    test('getter daoZhuEligibility 复用 6E-1 纯逻辑', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces, realmExp: _kSupremeGrandmasterRealmExp);
      final getter = cult.daoZhuEligibility;
      final direct = checkDaoZhuEligibility(
        profile: cult.state.profile,
        faction: Faction.li, // 主修 = li（唯一有感悟）
        isDeepestUnderstanding: false, // getter 默认 false
      );
      expect(getter.canGrant, direct.canGrant);
      expect(getter.nineTurnSatisfied, direct.nineTurnSatisfied);
      expect(getter.factionRealmSatisfied, direct.factionRealmSatisfied);
      expect(getter.daoTracesSatisfied, direct.daoTracesSatisfied);
      expect(
          getter.deepestUnderstandingSatisfied,
          direct.deepestUnderstandingSatisfied);
      expect(getter.failureReason, direct.failureReason);
    });

    test('语义隔离：高道痕/高境界不能绕过九转', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          nineTurnReached: false,
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp);
      final r =
          cult.grantDaoZhu(faction: Faction.li, isDeepestUnderstanding: true);
      expect(r.status, DaoZhuGrantStatus.failed);
      expect(r.failureReason, '尚未突破九转');
    });

    test('语义隔离：九转/高道痕不能绕过 deepestUnderstanding', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces, realmExp: _kSupremeGrandmasterRealmExp);
      final r = cult.grantDaoZhu(
          faction: Faction.li, isDeepestUnderstanding: false);
      expect(r.status, DaoZhuGrantStatus.failed);
      expect(r.failureReason, '当世理解最深未满足');
    });

    test('重复调用 grantDaoZhu 不覆盖第一次结果', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      _setupProfile(cult,
          traces: _kNineTurnDaoTraces, realmExp: _kSupremeGrandmasterRealmExp);
      final r1 = cult.grantDaoZhu(
        faction: Faction.li,
        isDeepestUnderstanding: true,
        eraId: 'era-1',
        now: DateTime(2026, 8, 24),
      );
      expect(r1.success, isTrue);

      final r2 = cult.grantDaoZhu(
        faction: Faction.li,
        isDeepestUnderstanding: true,
        eraId: 'era-2',
        now: DateTime(2027, 1, 1),
      );
      expect(r2.status, DaoZhuGrantStatus.alreadyGranted);
      expect(cult.state.profile.daoZhu!.eraId, 'era-1');
      expect(cult.state.profile.daoZhu!.crownedAt, DateTime(2026, 8, 24));
    });
  });
}
