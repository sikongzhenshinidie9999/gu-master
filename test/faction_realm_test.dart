import 'package:flutter_test/flutter_test.dart';

import 'package:sidequest/src/features/cultivation/data/dao.dart';
import 'package:sidequest/src/features/cultivation/data/faction_level.dart';
import 'package:sidequest/src/features/cultivation/data/player_profile.dart';
import 'package:sidequest/src/features/cultivation/logic/faction_realm.dart';

void main() {
  group('getFactionRealmProgress（由流派感悟派生）', () {
    test('感悟 0 → 普通，进度 0', () {
      final r = getFactionRealmProgress(Faction.li, 0);
      expect(r.faction, Faction.li);
      expect(r.level, FactionLevel.ordinary);
      expect(r.levelIndex, 0);
      expect(r.currentThreshold, 0);
      expect(r.nextThreshold, 1000);
      expect(r.progress, 0.0);
      expect(r.isCapped, isFalse);
    });

    test('感悟 999 → 普通，进度接近满', () {
      final r = getFactionRealmProgress(Faction.li, 999);
      expect(r.level, FactionLevel.ordinary);
      expect(r.progress, closeTo(0.999, 0.0001));
    });

    test('感悟 1000 → 大师', () {
      final r = getFactionRealmProgress(Faction.li, 1000);
      expect(r.level, FactionLevel.master);
      expect(r.levelIndex, 1);
      expect(r.currentThreshold, 1000);
      expect(r.nextThreshold, 5000);
      expect(r.progress, 0.0);
    });

    test('感悟 5000 → 宗师', () {
      final r = getFactionRealmProgress(Faction.li, 5000);
      expect(r.level, FactionLevel.grandmaster);
      expect(r.levelIndex, 2);
    });

    test('感悟 20000 → 大宗师', () {
      final r = getFactionRealmProgress(Faction.li, 20000);
      expect(r.level, FactionLevel.greatGrandmaster);
      expect(r.levelIndex, 3);
    });

    test('感悟 100000 → 无上大宗师（封顶）', () {
      final r = getFactionRealmProgress(Faction.li, 100000);
      expect(r.level, FactionLevel.supremeGrandmaster);
      expect(r.levelIndex, 4);
      expect(r.isCapped, isTrue);
      expect(r.nextThreshold, isNull);
      expect(r.progress, 1.0);
    });

    test('感悟 300000 → 仍无上大宗师，感悟继续累计', () {
      final r = getFactionRealmProgress(Faction.li, 300000);
      expect(r.level, FactionLevel.supremeGrandmaster);
      expect(r.isCapped, isTrue);
      expect(r.progress, 1.0);
    });

    test('三个流派互不影响', () {
      final li = getFactionRealmProgress(Faction.li, 5000);
      final zhi = getFactionRealmProgress(Faction.zhi, 100000);
      final lian = getFactionRealmProgress(Faction.lian, 0);
      expect(li.level, FactionLevel.grandmaster);
      expect(zhi.level, FactionLevel.supremeGrandmaster);
      expect(lian.level, FactionLevel.ordinary);
    });

    test('道主不由感悟值自动产生', () {
      final r = getFactionRealmProgress(Faction.lian, 99999999);
      expect(r.level, FactionLevel.supremeGrandmaster);
      expect(r.level, isNot(FactionLevel.daoLord));
    });
  });

  group('道痕与流派境界完全独立', () {
    test('道痕 300000、factionRealmExp=0 → 境界仍为普通', () {
      final profile = PlayerProfile(
        daoTraces: {DaoKind.li.index: 300000},
      );
      final realm = getFactionRealmProgress(
          Faction.li, profile.factionRealmExp[Faction.li.daoKind.index] ?? 0);
      expect(profile.daoTraces[DaoKind.li.index], 300000); // 道痕完整保留
      expect(realm.level, FactionLevel.ordinary); // 感悟为 0 → 普通
    });

    test('道痕 0、factionRealmExp=100000 → 无上大宗师', () {
      final profile = PlayerProfile(
        factionRealmExp: {Faction.li.daoKind.index: 100000},
      );
      final realm = getFactionRealmProgress(
          Faction.li, profile.factionRealmExp[Faction.li.daoKind.index] ?? 0);
      expect(profile.daoTraces[DaoKind.li.index], isNull); // 道痕为 0
      expect(realm.level, FactionLevel.supremeGrandmaster);
    });

    test('分别增加道痕与感悟时两者各自独立累加', () {
      final profile = PlayerProfile();
      profile.daoTraces[DaoKind.li.index] = 100;
      profile.factionRealmExp[Faction.li.daoKind.index] = 50;
      // 再各加一笔，互不影响
      profile.daoTraces[DaoKind.li.index] =
          (profile.daoTraces[DaoKind.li.index] ?? 0) + 100;
      profile.factionRealmExp[Faction.li.daoKind.index] =
          (profile.factionRealmExp[Faction.li.daoKind.index] ?? 0) + 50;
      expect(profile.daoTraces[DaoKind.li.index], 200);
      expect(profile.factionRealmExp[Faction.li.daoKind.index], 100);
      // 境界只由感悟决定
      final realm = getFactionRealmProgress(
          Faction.li, profile.factionRealmExp[Faction.li.daoKind.index] ?? 0);
      expect(realm.level, FactionLevel.ordinary); // 感悟 100 → 仍普通
    });

    test('factionLevels 旧字段不参与境界计算', () {
      final profile = PlayerProfile(
        factionLevels: {Faction.li.index: FactionLevel.supremeGrandmaster.index},
        factionRealmExp: {Faction.li.daoKind.index: 100},
      );
      final realm = getFactionRealmProgress(
          Faction.li, profile.factionRealmExp[Faction.li.daoKind.index] ?? 0);
      // 即使 factionLevels 被写成无上大宗师，境界仍由感悟（100 → 普通）决定
      expect(realm.level, FactionLevel.ordinary);
    });
  });
}
