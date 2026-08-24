import 'package:flutter_test/flutter_test.dart';

import 'package:sidequest/src/features/cultivation/data/dao.dart';
import 'package:sidequest/src/features/cultivation/data/faction_level.dart';
import 'package:sidequest/src/features/cultivation/logic/faction_realm.dart';

void main() {
  group('getFactionRealmProgress', () {
    test('道痕 0 → 普通，进度 0', () {
      final r = getFactionRealmProgress(Faction.li, 0);
      expect(r.faction, Faction.li);
      expect(r.level, FactionLevel.ordinary);
      expect(r.levelIndex, 0);
      expect(r.currentThreshold, 0);
      expect(r.nextThreshold, 1000);
      expect(r.progress, 0.0);
      expect(r.isCapped, isFalse);
    });

    test('道痕 999 → 普通，进度接近满', () {
      final r = getFactionRealmProgress(Faction.li, 999);
      expect(r.level, FactionLevel.ordinary);
      expect(r.progress, closeTo(0.999, 0.0001));
    });

    test('道痕 1000 → 大师', () {
      final r = getFactionRealmProgress(Faction.li, 1000);
      expect(r.level, FactionLevel.master);
      expect(r.levelIndex, 1);
      expect(r.currentThreshold, 1000);
      expect(r.nextThreshold, 5000);
      expect(r.progress, 0.0);
    });

    test('道痕 5000 → 宗师', () {
      final r = getFactionRealmProgress(Faction.li, 5000);
      expect(r.level, FactionLevel.grandmaster);
      expect(r.levelIndex, 2);
    });

    test('道痕 20000 → 大宗师', () {
      final r = getFactionRealmProgress(Faction.li, 20000);
      expect(r.level, FactionLevel.greatGrandmaster);
      expect(r.levelIndex, 3);
    });

    test('道痕 100000 → 无上大宗师（封顶）', () {
      final r = getFactionRealmProgress(Faction.li, 100000);
      expect(r.level, FactionLevel.supremeGrandmaster);
      expect(r.levelIndex, 4);
      expect(r.isCapped, isTrue);
      expect(r.nextThreshold, isNull);
      expect(r.progress, 1.0);
    });

    test('道痕 300000 → 仍无上大宗师，道痕继续累计', () {
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

    test('道主不由道痕数量自动产生', () {
      final r = getFactionRealmProgress(Faction.lian, 99999999);
      expect(r.level, FactionLevel.supremeGrandmaster);
      expect(r.level, isNot(FactionLevel.daoLord));
    });

    test('factionLevels 旧字段不参与派生', () {
      // 派生只看 daoTraces；函数签名不接受 factionLevels，天然无第二数据源
      final r = getFactionRealmProgress(Faction.zhi, 999);
      expect(r.level, FactionLevel.ordinary);
      expect(r.progress, closeTo(0.999, 0.0001));
    });
  });
}
