import 'package:flutter_test/flutter_test.dart';

import 'package:sidequest/src/features/cultivation/data/dao.dart';
import 'package:sidequest/src/features/cultivation/data/dao_zhu.dart';
import 'package:sidequest/src/features/cultivation/data/player_profile.dart';
import 'package:sidequest/src/features/cultivation/logic/dao_zhu_service.dart';
import 'package:sidequest/src/features/cultivation/logic/faction_realm_config.dart';
import 'package:sidequest/src/features/cultivation/logic/gu_power_config.dart';

/// 九转所需道痕（唯一来源：阶段五配置，测试不复制魔数）。
final int _kNineTurnDaoTraces = kDaoTracesRequiredByTurn[9]!;

/// 无上大宗师所需感悟（唯一来源：流派境界配置）。
final int _kSupremeGrandmasterRealmExp = kFactionRealmExpThresholds.last;

PlayerProfile _profile({
  bool nineTurnReached = true,
  Faction faction = Faction.li,
  int? traces,
  int? realmExp,
  DaoZhuState? daoZhu,
}) {
  final daoTraces = <int, int>{};
  final factionRealmExp = <int, int>{};
  if (traces != null) daoTraces[faction.daoKind.index] = traces;
  if (realmExp != null) factionRealmExp[faction.daoKind.index] = realmExp;
  return PlayerProfile(
    daoTraces: daoTraces,
    factionRealmExp: factionRealmExp,
    nineTurnReached: nineTurnReached,
    daoZhu: daoZhu,
  );
}

void main() {
  group('checkDaoZhuEligibility', () {
    test('九转未突破 → 不能授予', () {
      final r = checkDaoZhuEligibility(
        profile: _profile(
          nineTurnReached: false,
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        faction: Faction.li,
        isDeepestUnderstanding: true,
      );
      expect(r.nineTurnSatisfied, isFalse);
      expect(r.canGrant, isFalse);
      expect(r.failureReason, '尚未突破九转');
    });

    test('九转已突破 → nineTurnSatisfied true', () {
      final r = checkDaoZhuEligibility(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        faction: Faction.li,
        isDeepestUnderstanding: true,
      );
      expect(r.nineTurnSatisfied, isTrue);
      expect(r.canGrant, isTrue);
    });

    test('流派境界不足 → 不能授予', () {
      final r = checkDaoZhuEligibility(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp - 1,
        ),
        faction: Faction.li,
        isDeepestUnderstanding: true,
      );
      expect(r.factionRealmSatisfied, isFalse);
      expect(r.canGrant, isFalse);
      expect(r.failureReason, '该流派境界未达无上大宗师');
    });

    test('流派境界满足 → factionRealmSatisfied true', () {
      final r = checkDaoZhuEligibility(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        faction: Faction.li,
        isDeepestUnderstanding: true,
      );
      expect(r.factionRealmSatisfied, isTrue);
    });

    test('道痕不足 → 不能授予', () {
      final r = checkDaoZhuEligibility(
        profile: _profile(
          traces: _kNineTurnDaoTraces - 1,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        faction: Faction.li,
        isDeepestUnderstanding: true,
      );
      expect(r.daoTracesSatisfied, isFalse);
      expect(r.canGrant, isFalse);
      expect(r.failureReason, '该流派道痕未达九转要求');
    });

    test('道痕满足 → daoTracesSatisfied true', () {
      final r = checkDaoZhuEligibility(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        faction: Faction.li,
        isDeepestUnderstanding: true,
      );
      expect(r.daoTracesSatisfied, isTrue);
    });

    test('当世理解最深 false（默认）→ 不能授予', () {
      final r = checkDaoZhuEligibility(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        faction: Faction.li,
        // isDeepestUnderstanding 默认 false
      );
      expect(r.deepestUnderstandingSatisfied, isFalse);
      expect(r.canGrant, isFalse);
      expect(r.failureReason, '当世理解最深未满足');
    });

    test('当世理解最深 true → deepestUnderstandingSatisfied true', () {
      final r = checkDaoZhuEligibility(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        faction: Faction.li,
        isDeepestUnderstanding: true,
      );
      expect(r.deepestUnderstandingSatisfied, isTrue);
    });

    test('已存在 daoZhu → alreadyGranted，不可覆盖', () {
      final profile = _profile(
        traces: _kNineTurnDaoTraces,
        realmExp: _kSupremeGrandmasterRealmExp,
        daoZhu: DaoZhuState(
          faction: Faction.zhi.index,
          crownedAt: DateTime(2026, 8, 24),
          eraId: 'era-1',
        ),
      );
      final r = checkDaoZhuEligibility(
          profile: profile, faction: Faction.li, isDeepestUnderstanding: true);
      expect(r.alreadyGranted, isTrue);
      expect(r.canGrant, isFalse);
      expect(r.failureReason, '已成为道主');
    });

    test('四项资格全部满足 → canGrant true', () {
      final r = checkDaoZhuEligibility(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        faction: Faction.li,
        isDeepestUnderstanding: true,
      );
      expect(r.nineTurnSatisfied, isTrue);
      expect(r.factionRealmSatisfied, isTrue);
      expect(r.daoTracesSatisfied, isTrue);
      expect(r.deepestUnderstandingSatisfied, isTrue);
      expect(r.alreadyGranted, isFalse);
      expect(r.canGrant, isTrue);
      expect(r.failureReason, isNull);
    });

    test('各条件独立失败（分别只关闭一个）', () {
      final noNine = checkDaoZhuEligibility(
        profile: _profile(
          nineTurnReached: false,
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        faction: Faction.li,
        isDeepestUnderstanding: true,
      );
      final noRealm = checkDaoZhuEligibility(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp - 1,
        ),
        faction: Faction.li,
        isDeepestUnderstanding: true,
      );
      final noDao = checkDaoZhuEligibility(
        profile: _profile(
          traces: _kNineTurnDaoTraces - 1,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        faction: Faction.li,
        isDeepestUnderstanding: true,
      );
      final noDeepest = checkDaoZhuEligibility(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        faction: Faction.li,
        isDeepestUnderstanding: false,
      );

      expect(noNine.nineTurnSatisfied, isFalse);
      expect(noNine.factionRealmSatisfied, isTrue);
      expect(noNine.daoTracesSatisfied, isTrue);
      expect(noNine.deepestUnderstandingSatisfied, isTrue);
      expect(noNine.canGrant, isFalse);

      expect(noRealm.factionRealmSatisfied, isFalse);
      expect(noRealm.nineTurnSatisfied, isTrue);
      expect(noRealm.daoTracesSatisfied, isTrue);
      expect(noRealm.canGrant, isFalse);

      expect(noDao.daoTracesSatisfied, isFalse);
      expect(noDao.nineTurnSatisfied, isTrue);
      expect(noDao.factionRealmSatisfied, isTrue);
      expect(noDao.canGrant, isFalse);

      expect(noDeepest.deepestUnderstandingSatisfied, isFalse);
      expect(noDeepest.nineTurnSatisfied, isTrue);
      expect(noDeepest.factionRealmSatisfied, isTrue);
      expect(noDeepest.daoTracesSatisfied, isTrue);
      expect(noDeepest.canGrant, isFalse);
    });

    test('语义隔离：高道痕但未九转不能成为道主', () {
      final r = checkDaoZhuEligibility(
        profile: _profile(
          nineTurnReached: false,
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        faction: Faction.li,
        isDeepestUnderstanding: true,
      );
      expect(r.daoTracesSatisfied, isTrue);
      expect(r.nineTurnSatisfied, isFalse);
      expect(r.canGrant, isFalse);
    });

    test('语义隔离：九转+高道痕但境界不足不能成为道主', () {
      final r = checkDaoZhuEligibility(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: 100,
        ),
        faction: Faction.li,
        isDeepestUnderstanding: true,
      );
      expect(r.nineTurnSatisfied, isTrue);
      expect(r.daoTracesSatisfied, isTrue);
      expect(r.factionRealmSatisfied, isFalse);
      expect(r.canGrant, isFalse);
    });

    test('语义隔离：九转+高境界但道痕不足不能成为道主', () {
      final r = checkDaoZhuEligibility(
        profile: _profile(
          traces: 100,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        faction: Faction.li,
        isDeepestUnderstanding: true,
      );
      expect(r.factionRealmSatisfied, isTrue);
      expect(r.daoTracesSatisfied, isFalse);
      expect(r.canGrant, isFalse);
    });

    test('语义隔离：全部满足但 deepest=false 不能成为道主', () {
      final r = checkDaoZhuEligibility(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        faction: Faction.li,
        isDeepestUnderstanding: false,
      );
      expect(r.nineTurnSatisfied, isTrue);
      expect(r.factionRealmSatisfied, isTrue);
      expect(r.daoTracesSatisfied, isTrue);
      expect(r.deepestUnderstandingSatisfied, isFalse);
      expect(r.canGrant, isFalse);
    });

    test('九转道痕阈值单一来源：恰好达到满足、低于 1 不满足', () {
      final at = checkDaoZhuEligibility(
        profile: _profile(
          traces: _kNineTurnDaoTraces,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        faction: Faction.li,
        isDeepestUnderstanding: true,
      );
      final below = checkDaoZhuEligibility(
        profile: _profile(
          traces: _kNineTurnDaoTraces - 1,
          realmExp: _kSupremeGrandmasterRealmExp,
        ),
        faction: Faction.li,
        isDeepestUnderstanding: true,
      );
      expect(at.daoTracesSatisfied, isTrue);
      expect(below.daoTracesSatisfied, isFalse);
    });

    test('流派独立：智道资格只读取智道道痕与感悟', () {
      final profile = PlayerProfile(
        daoTraces: {Faction.li.daoKind.index: _kNineTurnDaoTraces},
        factionRealmExp: {
          Faction.li.daoKind.index: _kSupremeGrandmasterRealmExp
        },
        nineTurnReached: true,
      );
      final r = checkDaoZhuEligibility(
          profile: profile, faction: Faction.zhi, isDeepestUnderstanding: true);
      expect(r.daoTracesSatisfied, isFalse); // 智道道痕为 0
      expect(r.factionRealmSatisfied, isFalse); // 智道感悟为 0
      expect(r.canGrant, isFalse);
    });

    test('纯函数：不修改输入 profile，重复调用结果一致', () {
      final profile = _profile(
        traces: _kNineTurnDaoTraces,
        realmExp: _kSupremeGrandmasterRealmExp,
      );
      final daoBefore = Map.of(profile.daoTraces);
      final expBefore = Map.of(profile.factionRealmExp);
      final nineBefore = profile.nineTurnReached;
      final xianBefore = profile.xianYuan;
      final daoZhuBefore = profile.daoZhu;

      final r1 = checkDaoZhuEligibility(
          profile: profile, faction: Faction.li, isDeepestUnderstanding: true);
      final r2 = checkDaoZhuEligibility(
          profile: profile, faction: Faction.li, isDeepestUnderstanding: true);
      expect(r1.canGrant, isTrue);
      expect(r2.canGrant, isTrue);
      expect(r1.failureReason, r2.failureReason);

      // 输入未被修改
      expect(profile.daoTraces, daoBefore);
      expect(profile.factionRealmExp, expBefore);
      expect(profile.nineTurnReached, nineBefore);
      expect(profile.xianYuan, xianBefore);
      expect(profile.daoZhu, daoZhuBefore);
    });
  });
}
