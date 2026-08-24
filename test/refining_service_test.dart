import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:sidequest/src/features/cultivation/data/dao.dart';
import 'package:sidequest/src/features/cultivation/data/faction_level.dart';
import 'package:sidequest/src/features/cultivation/logic/refining_config.dart';
import 'package:sidequest/src/features/cultivation/logic/refining_service.dart';

/// 固定值 Random，用于确定性控制成功/失败。
class _FixedRandom implements Random {
  final double doubleValue;
  final int intValue;

  _FixedRandom(this.doubleValue, [this.intValue = 0]);

  @override
  double nextDouble() => doubleValue;

  @override
  int nextInt(int max) => intValue.clamp(0, max - 1);

  @override
  bool nextBool() => doubleValue < 0.5;
}

void main() {
  group('refiningSuccessRate', () {
    test('转数越高成功率越低', () {
      final low = refiningSuccessRate(
          insectTurn: 1, lianDaoLevel: FactionLevel.ordinary);
      final high = refiningSuccessRate(
          insectTurn: 9, lianDaoLevel: FactionLevel.ordinary);
      expect(high, lessThan(low));
    });

    test('炼道境界越高成功率越高', () {
      final low = refiningSuccessRate(
          insectTurn: 5, lianDaoLevel: FactionLevel.master);
      final high = refiningSuccessRate(
          insectTurn: 5, lianDaoLevel: FactionLevel.supremeGrandmaster);
      expect(high, greaterThan(low));
    });

    test('成功率永远在 min/max 范围', () {
      for (var turn = 1; turn <= 9; turn++) {
        for (final level in FactionLevel.values) {
          final rate = refiningSuccessRate(insectTurn: turn, lianDaoLevel: level);
          expect(rate, greaterThanOrEqualTo(kRefineMinSuccessRate));
          expect(rate, lessThanOrEqualTo(kRefineMaxSuccessRate));
        }
      }
    });
  });

  group('refineGuInsect', () {
    Map<String, int> fullInventory() => {
      'bronze_sand': 10,
      'iron_powder': 10,
      'blood_lotus': 10,
      'nine_turn_spirit': 10,
    };

    test('缺材料不能炼', () {
      final result = refineGuInsect(
        insectDefinitionId: 'bronze_beetle',
        lianDaoLevel: FactionLevel.master,
        inventory: {'bronze_sand': 1},
        random: _FixedRandom(0.0),
      );
      expect(result.success, isFalse);
      expect(result.failureReason, '蛊材不足');
    });

    test('找不到蛊方不能炼', () {
      final result = refineGuInsect(
        insectDefinitionId: 'no_such_insect',
        lianDaoLevel: FactionLevel.master,
        inventory: fullInventory(),
        random: _FixedRandom(0.0),
      );
      expect(result.success, isFalse);
      expect(result.failureReason, '未找到蛊方');
    });

    test('成功消耗材料数量正确', () {
      final result = refineGuInsect(
        insectDefinitionId: 'bronze_beetle',
        lianDaoLevel: FactionLevel.supremeGrandmaster,
        inventory: fullInventory(),
        random: _FixedRandom(0.0), // 必成
      );
      expect(result.success, isTrue);
      final consumed = {
        for (final m in result.consumedMaterials) m.materialId: m.quantity,
      };
      expect(consumed['bronze_sand'], 3);
      expect(consumed['iron_powder'], 1);
    });

    test('成功生成正确蛊虫', () {
      final result = refineGuInsect(
        insectDefinitionId: 'bronze_beetle',
        lianDaoLevel: FactionLevel.grandmaster,
        inventory: fullInventory(),
        random: _FixedRandom(0.0),
      );
      expect(result.success, isTrue);
      final insect = result.gainedInsect!;
      expect(insect.definitionId, 'bronze_beetle');
      expect(insect.name, '青铜甲蛊');
      expect(insect.turn, 1);
      expect(insect.faction, Faction.li.index);
    });

    test('quality 始终在合法范围', () {
      // 血莲蛊 minQuality=1 maxQuality=2：用 intValue 控制到两端
      final low = refineGuInsect(
        insectDefinitionId: 'blood_lotus_gu',
        lianDaoLevel: FactionLevel.supremeGrandmaster,
        inventory: fullInventory(),
        random: _FixedRandom(0.0, 0),
      );
      final high = refineGuInsect(
        insectDefinitionId: 'blood_lotus_gu',
        lianDaoLevel: FactionLevel.supremeGrandmaster,
        inventory: fullInventory(),
        random: _FixedRandom(0.0, 999),
      );
      expect(low.gainedInsect!.quality, 1);
      expect(high.gainedInsect!.quality, 2);
      expect(low.gainedInsect!.quality, inInclusiveRange(1, 2));
      expect(high.gainedInsect!.quality, inInclusiveRange(1, 2));
    });

    test('refinedDaoLevel 正确记录', () {
      final result = refineGuInsect(
        insectDefinitionId: 'bronze_beetle',
        lianDaoLevel: FactionLevel.grandmaster,
        inventory: fullInventory(),
        random: _FixedRandom(0.0),
      );
      expect(result.success, isTrue);
      expect(result.gainedInsect!.refinedDaoLevel, FactionLevel.grandmaster.index);
    });

    test('Random 可以控制成功/失败', () {
      final ok = refineGuInsect(
        insectDefinitionId: 'bronze_beetle',
        lianDaoLevel: FactionLevel.supremeGrandmaster,
        inventory: fullInventory(),
        random: _FixedRandom(0.0),
      );
      final fail = refineGuInsect(
        insectDefinitionId: 'bronze_beetle',
        lianDaoLevel: FactionLevel.supremeGrandmaster,
        inventory: fullInventory(),
        random: _FixedRandom(1.0),
      );
      expect(ok.success, isTrue);
      expect(fail.success, isFalse);
      expect(fail.failureReason, '炼制失败');
    });
  });
}
