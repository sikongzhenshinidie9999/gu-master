import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:sidequest/src/features/cultivation/data/dao.dart';
import 'package:sidequest/src/features/cultivation/data/dao_zhu.dart';
import 'package:sidequest/src/features/cultivation/data/faction_level.dart';
import 'package:sidequest/src/features/cultivation/data/gu_insect.dart';
import 'package:sidequest/src/features/cultivation/data/gu_material.dart';
import 'package:sidequest/src/features/cultivation/data/player_profile.dart';
import 'package:sidequest/src/features/cultivation/data/tribulation_record.dart';
import 'package:sidequest/src/features/cultivation/logic/cultivation_provider.dart';
import 'package:sidequest/src/features/cultivation/logic/faction_realm.dart';
import 'package:sidequest/src/features/cultivation/logic/gu_power_config.dart';
import 'package:sidequest/src/features/cultivation/logic/gu_power_service.dart';
import 'package:sidequest/src/features/quests/data/quest_model.dart';

/// 构造蛊虫（definitionId 找不到时使用快照字段兜底）。
GuInsect _insect({
  String definitionId = 'bronze_beetle',
  int turn = 1,
  int faction = 0, // Faction.li.index
  int quality = 0,
  int refinedDaoLevel = 0,
  String id = 'g1',
}) =>
    GuInsect(
      id: id,
      turn: turn,
      refinedDaoLevel: refinedDaoLevel,
      definitionId: definitionId,
      faction: faction,
      quality: quality,
    );

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
    tempDir = await Directory.systemTemp.createTemp('gu_power_test_');
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

  group('getGuInsectPower 纯函数', () {
    test('0 道痕时 daoFactor = 1', () {
      final r = getGuInsectPower(
        insect: _insect(
            definitionId: 'bronze_beetle',
            turn: 1,
            faction: Faction.li.index,
            quality: 0),
        daoTraces: {},
      );
      expect(r.daoMultiplier, 1.0);
      expect(r.unlockRatio, 1.0); // 1 转 required=0 → 完全解锁
      expect(
        r.totalPower,
        closeTo(
            kInsectBasePowerByTurn[1]! * kQualityPowerMultipliers[0], 1e-9),
      );
    });

    test('高道痕时威能不会超过配置上限', () {
      final r = getGuInsectPower(
        insect: _insect(
            definitionId: 'nine_turn_worm',
            turn: 9,
            faction: Faction.li.index,
            quality: 2),
        daoTraces: {DaoKind.li.index: (1 << 31) - 1},
      );
      expect(r.daoMultiplier, lessThanOrEqualTo(1 + kDaoMaxMultiplier + 1e-9));
      expect(r.totalPower.isFinite, isTrue);
      expect(
        r.totalPower,
        lessThanOrEqualTo(kInsectBasePowerByTurn[9]! *
                kQualityPowerMultipliers[2] *
                (1 + kDaoMaxMultiplier) +
            1e-9),
      );
    });

    test('力道蛊虫只读取力道道痕', () {
      // 智道/炼道极高，力道为 0 → 无加成
      final noLi = getGuInsectPower(
        insect: _insect(
            definitionId: 'bronze_beetle',
            turn: 1,
            faction: Faction.li.index,
            quality: 0),
        daoTraces: {DaoKind.zhi.index: 100000, DaoKind.lian.index: 100000},
      );
      expect(noLi.daoMultiplier, 1.0);

      final withLi = getGuInsectPower(
        insect: _insect(
            definitionId: 'bronze_beetle',
            turn: 1,
            faction: Faction.li.index,
            quality: 0),
        daoTraces: {DaoKind.li.index: 100000},
      );
      expect(withLi.daoMultiplier, greaterThan(1.0));
    });

    test('智道蛊虫只读取智道道痕', () {
      final noZhi = getGuInsectPower(
        insect: _insect(
            definitionId: 'blood_lotus_gu',
            turn: 5,
            faction: Faction.zhi.index,
            quality: 0),
        daoTraces: {DaoKind.li.index: 100000, DaoKind.lian.index: 100000},
      );
      expect(noZhi.daoMultiplier, 1.0);

      final withZhi = getGuInsectPower(
        insect: _insect(
            definitionId: 'blood_lotus_gu',
            turn: 5,
            faction: Faction.zhi.index,
            quality: 0),
        daoTraces: {DaoKind.zhi.index: 100000},
      );
      expect(withZhi.daoMultiplier, greaterThan(1.0));
    });

    test('炼道蛊虫只读取炼道道痕', () {
      final noLian = getGuInsectPower(
        insect: _insect(
            definitionId: 'iron_centipede',
            turn: 3,
            faction: Faction.lian.index,
            quality: 0),
        daoTraces: {DaoKind.li.index: 100000, DaoKind.zhi.index: 100000},
      );
      expect(noLian.daoMultiplier, 1.0);

      final withLian = getGuInsectPower(
        insect: _insect(
            definitionId: 'iron_centipede',
            turn: 3,
            faction: Faction.lian.index,
            quality: 0),
        daoTraces: {DaoKind.lian.index: 100000},
      );
      expect(withLian.daoMultiplier, greaterThan(1.0));
    });

    test('同道痕下 9 转 > 5 转 > 3 转 > 1 转', () {
      final traces = {
        DaoKind.li.index: 50000,
        DaoKind.zhi.index: 50000,
        DaoKind.lian.index: 50000,
      };
      final p1 = getGuInsectPower(
        insect: _insect(
            definitionId: 'bronze_beetle',
            turn: 1,
            faction: Faction.li.index,
            quality: 0),
        daoTraces: traces,
      ).totalPower;
      final p3 = getGuInsectPower(
        insect: _insect(
            definitionId: 'iron_centipede',
            turn: 3,
            faction: Faction.lian.index,
            quality: 0),
        daoTraces: traces,
      ).totalPower;
      final p5 = getGuInsectPower(
        insect: _insect(
            definitionId: 'blood_lotus_gu',
            turn: 5,
            faction: Faction.zhi.index,
            quality: 0),
        daoTraces: traces,
      ).totalPower;
      final p9 = getGuInsectPower(
        insect: _insect(
            definitionId: 'nine_turn_worm',
            turn: 9,
            faction: Faction.li.index,
            quality: 0),
        daoTraces: traces,
      ).totalPower;
      expect(p9, greaterThan(p5));
      expect(p5, greaterThan(p3));
      expect(p3, greaterThan(p1));
    });

    test('1 转吃满道痕仍小于 9 转 0 道痕', () {
      final turn1Max = getGuInsectPower(
        insect: _insect(
            definitionId: 'bronze_beetle',
            turn: 1,
            faction: Faction.li.index,
            quality: 2),
        daoTraces: {DaoKind.li.index: (1 << 31) - 1},
      );
      final turn9Zero = getGuInsectPower(
        insect: _insect(
            definitionId: 'nine_turn_worm',
            turn: 9,
            faction: Faction.li.index,
            quality: 0),
        daoTraces: {},
      );
      expect(turn1Max.totalPower, lessThan(turn9Zero.totalPower));
    });

    test('特殊 > 稀有 > 普通', () {
      final dao = {DaoKind.li.index: 5000};
      final ordinary = getGuInsectPower(
        insect: _insect(
            definitionId: 'bronze_beetle',
            turn: 1,
            faction: Faction.li.index,
            quality: 0),
        daoTraces: dao,
      ).totalPower;
      final rare = getGuInsectPower(
        insect: _insect(
            definitionId: 'bronze_beetle',
            turn: 1,
            faction: Faction.li.index,
            quality: 1),
        daoTraces: dao,
      ).totalPower;
      final special = getGuInsectPower(
        insect: _insect(
            definitionId: 'bronze_beetle',
            turn: 1,
            faction: Faction.li.index,
            quality: 2),
        daoTraces: dao,
      ).totalPower;
      expect(special, greaterThan(rare));
      expect(rare, greaterThan(ordinary));
    });

    test('非法 faction 不崩溃', () {
      final r = getGuInsectPower(
        insect: _insect(definitionId: 'nope', turn: 3, faction: 99, quality: 1),
        daoTraces: {},
      );
      expect(r.totalPower.isFinite, isTrue);
      expect(r.daoMultiplier, 1.0);
      expect(r.unlockRatio, 0.0);
    });

    test('2^31-1 等极端道痕值不会产生 NaN / Infinity', () {
      final r = getGuInsectPower(
        insect: _insect(
            definitionId: 'nine_turn_worm',
            turn: 9,
            faction: Faction.li.index,
            quality: 2),
        daoTraces: {DaoKind.li.index: (1 << 31) - 1},
      );
      expect(r.daoMultiplier.isFinite, isTrue);
      expect(r.totalPower.isFinite, isTrue);
      expect(r.daoMultiplier.isNaN, isFalse);
      expect(r.totalPower.isNaN, isFalse);
    });

    test('九转 + 300000 道痕时 unlockRatio 接近 1', () {
      final r = getGuInsectPower(
        insect: _insect(
            definitionId: 'nine_turn_worm',
            turn: 9,
            faction: Faction.li.index,
            quality: 1),
        daoTraces: {DaoKind.li.index: 300000},
      );
      expect(r.unlockRatio, closeTo(1.0, 1e-9));
      expect(r.daoMultiplier, greaterThan(1.0));
    });

    test('九转 + 0 道痕时明显受到压制', () {
      final zero = getGuInsectPower(
        insect: _insect(
            definitionId: 'nine_turn_worm',
            turn: 9,
            faction: Faction.li.index,
            quality: 1),
        daoTraces: {},
      );
      final full = getGuInsectPower(
        insect: _insect(
            definitionId: 'nine_turn_worm',
            turn: 9,
            faction: Faction.li.index,
            quality: 1),
        daoTraces: {DaoKind.li.index: 300000},
      );
      expect(zero.unlockRatio, 0.0);
      expect(zero.daoMultiplier, 1.0);
      expect(zero.totalPower, lessThan(full.totalPower));
      // 明显受到压制：0 道痕不足 300000 道痕时的 60%
      expect(zero.totalPower, lessThan(full.totalPower * 0.6));
    });

    test('definitionId 不存在时使用 GuInsect 快照计算', () {
      final r = getGuInsectPower(
        insect: _insect(
            definitionId: 'nope',
            turn: 3,
            faction: Faction.zhi.index,
            quality: 1),
        daoTraces: {DaoKind.zhi.index: 10000},
      );
      // 快照兜底：turn=3 / quality=1
      expect(r.basePower, kInsectBasePowerByTurn[3]);
      expect(r.qualityMultiplier, kQualityPowerMultipliers[1]);
      // 快照流派 zhi → 读取智道道痕，获得加成
      expect(r.daoMultiplier, greaterThan(1.0));
    });

    test('重复调用结果一致', () {
      final insect = _insect(
          definitionId: 'iron_centipede',
          turn: 3,
          faction: Faction.lian.index,
          quality: 2);
      final daoTraces = {DaoKind.lian.index: 25000};
      final a = getGuInsectPower(insect: insect, daoTraces: daoTraces);
      final b = getGuInsectPower(insect: insect, daoTraces: daoTraces);
      expect(a.basePower, b.basePower);
      expect(a.qualityMultiplier, b.qualityMultiplier);
      expect(a.daoMultiplier, b.daoMultiplier);
      expect(a.unlockRatio, b.unlockRatio);
      expect(a.totalPower, b.totalPower);
    });

    test('quality 越界安全处理', () {
      final low = getGuInsectPower(
        insect: _insect(
            definitionId: 'bronze_beetle',
            turn: 1,
            faction: Faction.li.index,
            quality: -1),
        daoTraces: {},
      );
      final high = getGuInsectPower(
        insect: _insect(
            definitionId: 'bronze_beetle',
            turn: 1,
            faction: Faction.li.index,
            quality: 99),
        daoTraces: {},
      );
      expect(low.qualityMultiplier, kQualityPowerMultipliers.first);
      expect(high.qualityMultiplier, kQualityPowerMultipliers.last);
      expect(low.totalPower.isFinite, isTrue);
      expect(high.totalPower.isFinite, isTrue);
    });
  });

  group('calculateFactionPower 纯函数', () {
    test('factionPower 正确汇总同流派蛊虫', () {
      final insects = [
        _insect(
            definitionId: 'bronze_beetle',
            turn: 1,
            faction: Faction.li.index,
            quality: 0),
        _insect(
            definitionId: 'nine_turn_worm',
            turn: 9,
            faction: Faction.li.index,
            quality: 1),
        _insect(
            definitionId: 'blood_lotus_gu',
            turn: 5,
            faction: Faction.zhi.index,
            quality: 0),
      ];
      final daoTraces = {
        DaoKind.li.index: 50000,
        DaoKind.zhi.index: 0,
        DaoKind.lian.index: 0,
      };

      final liPower = calculateFactionPower(
          faction: Faction.li,
          daoTraces: daoTraces,
          insects: insects);
      final expectedLi =
          getGuInsectPower(insect: insects[0], daoTraces: daoTraces).totalPower +
              getGuInsectPower(insect: insects[1], daoTraces: daoTraces)
                  .totalPower;
      expect(liPower, closeTo(expectedLi, 1e-9));

      final zhiPower = calculateFactionPower(
          faction: Faction.zhi,
          daoTraces: daoTraces,
          insects: insects);
      final expectedZhi =
          getGuInsectPower(insect: insects[2], daoTraces: daoTraces).totalPower;
      expect(zhiPower, closeTo(expectedZhi, 1e-9));
    });
  });

  group('语义隔离（Provider 只读入口）', () {
    test('修改 factionRealmExp 不影响威能', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final profile = cult.state.profile;
      profile.guInsects.add(_insect(
          definitionId: 'bronze_beetle',
          turn: 1,
          faction: Faction.li.index,
          quality: 1));
      profile.daoTraces[DaoKind.li.index] = 5000;
      final insect = profile.guInsects.first;

      final before = cult.insectPower(insect);
      // 大幅修改感悟（境界成长），与道痕完全独立
      profile.factionRealmExp[DaoKind.li.index] = 100000;
      final after = cult.insectPower(insect);

      expect(after.totalPower, before.totalPower);
      expect(after.daoMultiplier, before.daoMultiplier);
      // 境界确实变化，但威能不变
      final realm = getFactionRealmProgress(
          Faction.li, profile.factionRealmExp[Faction.li.daoKind.index] ?? 0);
      expect(realm.level, FactionLevel.supremeGrandmaster);
    });

    test('修改 daoTraces 不影响 FactionLevel', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final profile = cult.state.profile;

      final levelBefore = getFactionRealmProgress(
              Faction.li,
              profile.factionRealmExp[Faction.li.daoKind.index] ?? 0)
          .level;
      profile.daoTraces[DaoKind.li.index] = 300000; // 道痕极高
      final levelAfter = getFactionRealmProgress(
              Faction.li,
              profile.factionRealmExp[Faction.li.daoKind.index] ?? 0)
          .level;
      expect(levelAfter, levelBefore);
      expect(levelAfter, FactionLevel.ordinary); // 感悟 0 → 普通

      // 道痕确实参与威能
      profile.guInsects.add(_insect(
          definitionId: 'nine_turn_worm',
          turn: 9,
          faction: Faction.li.index,
          quality: 1));
      final power = cult.insectPower(profile.guInsects.first);
      expect(power.daoMultiplier, greaterThan(1.0));
    });
  });
}
