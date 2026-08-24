import 'package:flutter_test/flutter_test.dart';

import 'package:sidequest/src/features/cultivation/data/dao.dart';
import 'package:sidequest/src/features/cultivation/data/faction_level.dart';
import 'package:sidequest/src/features/cultivation/data/player_profile.dart';
import 'package:sidequest/src/features/cultivation/logic/faction_realm_config.dart';
import 'package:sidequest/src/features/cultivation/logic/gu_power_config.dart';
import 'package:sidequest/src/features/cultivation/logic/nine_turn_prerequisites.dart';

/// 九转所需道痕（唯一来源：阶段五配置，测试不复制魔数）。
final int _kNineTurnDaoTraces = kDaoTracesRequiredByTurn[9]!;

/// 无上大宗师所需感悟（唯一来源：流派境界配置）。
final int _kSupremeGrandmasterRealmExp = kFactionRealmExpThresholds.last;

PlayerProfile _profile({
  Faction primary = Faction.li,
  int? traces,
  int? realmExp,
  int? xianYuan,
}) {
  final daoTraces = <int, int>{};
  final factionRealmExp = <int, int>{};
  if (traces != null) daoTraces[primary.daoKind.index] = traces;
  if (realmExp != null) factionRealmExp[primary.daoKind.index] = realmExp;
  return PlayerProfile(
    daoTraces: daoTraces,
    factionRealmExp: factionRealmExp,
    xianYuan: xianYuan ?? XianYuanType.baili.index,
  );
}

void main() {
  group('resolvePrimaryFaction', () {
    test('按 factionRealmExp 最高值选择主修流派', () {
      final p = PlayerProfile(
        factionRealmExp: {
          Faction.li.daoKind.index: 100,
          Faction.zhi.daoKind.index: 5000,
          Faction.lian.daoKind.index: 50,
        },
      );
      expect(resolvePrimaryFaction(p), Faction.zhi);
    });

    test('相同值时结果稳定（Faction.values 靠前优先）', () {
      final p = PlayerProfile(
        factionRealmExp: {
          Faction.li.daoKind.index: 100,
          Faction.zhi.daoKind.index: 100,
          Faction.lian.daoKind.index: 0,
        },
      );
      expect(resolvePrimaryFaction(p), Faction.li);
      // 重复调用结果一致
      expect(resolvePrimaryFaction(p), resolvePrimaryFaction(p));
    });

    test('全部缺失/为 0 时返回 null，不崩溃', () {
      expect(resolvePrimaryFaction(PlayerProfile()), isNull);
      final zero = PlayerProfile(
        factionRealmExp: {
          Faction.li.daoKind.index: 0,
          Faction.zhi.daoKind.index: 0,
          Faction.lian.daoKind.index: 0,
        },
      );
      expect(resolvePrimaryFaction(zero), isNull);
    });

    test('忽略 daoTraces：道痕最高不决定主修流派', () {
      final p = PlayerProfile(
        daoTraces: {Faction.zhi.daoKind.index: 999999},
        factionRealmExp: {Faction.li.daoKind.index: 10},
      );
      expect(resolvePrimaryFaction(p), Faction.li);
    });
  });

  group('checkNineTurnPrerequisites', () {
    test('四条件全部满足 → canBreakthrough == true', () {
      final r = checkNineTurnPrerequisites(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        tribulationSatisfied: true,
      );
      expect(r.canBreakthrough, isTrue);
      expect(r.daoTracesSatisfied, isTrue);
      expect(r.factionRealmSatisfied, isTrue);
      expect(r.xianYuanSatisfied, isTrue);
      expect(r.tribulationSatisfied, isTrue);
    });

    test('道痕不足 → 不能突破', () {
      final r = checkNineTurnPrerequisites(
        profile: _profile(
          traces: _kNineTurnDaoTraces - 1,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        tribulationSatisfied: true,
      );
      expect(r.daoTracesSatisfied, isFalse);
      expect(r.canBreakthrough, isFalse);
    });

    test('境界不足 → 不能突破', () {
      final r = checkNineTurnPrerequisites(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp - 1,
        ),
        tribulationSatisfied: true,
      );
      expect(r.factionRealmSatisfied, isFalse);
      expect(r.factionRealmLevel, FactionLevel.greatGrandmaster);
      expect(r.canBreakthrough, isFalse);
    });

    test('仙元错误 → 不能突破', () {
      final r = checkNineTurnPrerequisites(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
          xianYuan: XianYuanType.none.index,
        ),
        tribulationSatisfied: true,
      );
      expect(r.xianYuanSatisfied, isFalse);
      expect(r.canBreakthrough, isFalse);
    });

    test('渡劫未完成 → 不能突破', () {
      final r = checkNineTurnPrerequisites(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        tribulationSatisfied: false,
      );
      expect(r.tribulationSatisfied, isFalse);
      expect(r.canBreakthrough, isFalse);
    });

    test('四条件独立性：分别只关闭一个条件', () {
      final base = _profile(
        traces: _kNineTurnDaoTraces,
        realmExp: _kSupremeGrandmasterRealmExp,
      );

      final daoOff = checkNineTurnPrerequisites(
        profile: _profile(
          traces: _kNineTurnDaoTraces - 1,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        tribulationSatisfied: true,
      );
      final realmOff = checkNineTurnPrerequisites(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp - 1,
        ),
        tribulationSatisfied: true,
      );
      final xianOff = checkNineTurnPrerequisites(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
          xianYuan: XianYuanType.huangxing.index,
        ),
        tribulationSatisfied: true,
      );
      final triOff = checkNineTurnPrerequisites(
        profile: base,
        tribulationSatisfied: false,
      );

      expect(daoOff.canBreakthrough, isFalse);
      expect(daoOff.daoTracesSatisfied, isFalse);
      expect(daoOff.factionRealmSatisfied, isTrue);
      expect(daoOff.xianYuanSatisfied, isTrue);
      expect(daoOff.tribulationSatisfied, isTrue);

      expect(realmOff.canBreakthrough, isFalse);
      expect(realmOff.daoTracesSatisfied, isTrue);
      expect(realmOff.factionRealmSatisfied, isFalse);
      expect(realmOff.xianYuanSatisfied, isTrue);
      expect(realmOff.tribulationSatisfied, isTrue);

      expect(xianOff.canBreakthrough, isFalse);
      expect(xianOff.daoTracesSatisfied, isTrue);
      expect(xianOff.factionRealmSatisfied, isTrue);
      expect(xianOff.xianYuanSatisfied, isFalse);
      expect(xianOff.tribulationSatisfied, isTrue);

      expect(triOff.canBreakthrough, isFalse);
      expect(triOff.daoTracesSatisfied, isTrue);
      expect(triOff.factionRealmSatisfied, isTrue);
      expect(triOff.xianYuanSatisfied, isTrue);
      expect(triOff.tribulationSatisfied, isFalse);
    });

    test('道痕与境界绝不互相转换', () {
      // 高道痕 + 低感悟（普通境界）→ 道痕满足但境界不足
      final highDaoLowExp = checkNineTurnPrerequisites(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: 100,
        ),
        tribulationSatisfied: true,
      );
      expect(highDaoLowExp.primaryFaction, Faction.li);
      expect(highDaoLowExp.daoTracesSatisfied, isTrue);
      expect(highDaoLowExp.factionRealmSatisfied, isFalse);
      expect(highDaoLowExp.factionRealmLevel, FactionLevel.ordinary);
      expect(highDaoLowExp.canBreakthrough, isFalse);

      // 低道痕 + 无上大宗师 → 境界满足但道痕不足
      final lowDaoHighExp = checkNineTurnPrerequisites(
        profile: _profile(
          traces: 0,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        tribulationSatisfied: true,
      );
      expect(lowDaoHighExp.factionRealmSatisfied, isTrue);
      expect(lowDaoHighExp.daoTracesSatisfied, isFalse);
      expect(lowDaoHighExp.canBreakthrough, isFalse);
    });

    test('白荔仙元满足，其余仙元不满足', () {
      for (final type in XianYuanType.values) {
        final r = checkNineTurnPrerequisites(
          profile: _profile(
            traces: _kNineTurnDaoTraces,
            realmExp: _kSupremeGrandmasterRealmExp,
            xianYuan: type.index,
          ),
          tribulationSatisfied: true,
        );
        expect(r.xianYuanSatisfied, type == XianYuanType.baili,
            reason: '仙元 ${type.label} 的满足状态');
      }
    });

    test('九转阈值单一来源：daoTraceRequirement == kDaoTracesRequiredByTurn[9]', () {
      final r = checkNineTurnPrerequisites(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        tribulationSatisfied: true,
      );
      expect(r.daoTraceRequirement, kDaoTracesRequiredByTurn[9]);
      expect(r.daoTraceRequirement, _kNineTurnDaoTraces);
      expect(r.daoTracesSatisfied, isTrue); // 正好等于阈值 → 满足

      final below = checkNineTurnPrerequisites(
        profile: _profile(
          traces: _kNineTurnDaoTraces - 1,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        tribulationSatisfied: true,
      );
      expect(below.daoTracesSatisfied, isFalse);
    });

    test('非法/缺失数据安全返回 false，不崩溃', () {
      // 全部缺失
      final empty = checkNineTurnPrerequisites(
        profile: PlayerProfile(),
        tribulationSatisfied: true,
      );
      expect(empty.canBreakthrough, isFalse);
      expect(empty.primaryFaction, isNull);
      expect(empty.daoTracesSatisfied, isFalse);
      expect(empty.factionRealmSatisfied, isFalse);
      expect(empty.xianYuanSatisfied, isFalse); // xianYuan 默认 0 = none

      // 非法 xianYuan
      final badXian = checkNineTurnPrerequisites(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
          xianYuan: 99,
        ),
        tribulationSatisfied: true,
      );
      expect(badXian.xianYuanSatisfied, isFalse);
      expect(badXian.canBreakthrough, isFalse);

      // 越界 key 被忽略，不崩溃
      final weird = PlayerProfile(
        daoTraces: {
          99: 999999,
          Faction.li.daoKind.index: _kNineTurnDaoTraces,
        },
        factionRealmExp: {
          99: 999999,
          Faction.li.daoKind.index: _kSupremeGrandmasterRealmExp,
        },
        xianYuan: XianYuanType.baili.index,
      );
      final weirdR = checkNineTurnPrerequisites(
        profile: weird,
        tribulationSatisfied: true,
      );
      expect(weirdR.canBreakthrough, isTrue);

      // 负道痕 → 不满足，不崩溃
      final negR = checkNineTurnPrerequisites(
        profile: _profile(
          traces: -5,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        tribulationSatisfied: true,
      );
      expect(negR.daoTracesSatisfied, isFalse);
      expect(negR.canBreakthrough, isFalse);
    });
  });
}
