import 'package:flutter_test/flutter_test.dart';

import 'package:sidequest/src/features/cultivation/data/tribulation_record.dart';
import 'package:sidequest/src/features/cultivation/logic/tribulation_trigger.dart';

void main() {
  group('tribulationMilestone', () {
    test('六转里程碑（跨度 1000：2500→3500）', () {
      expect(tribulationMilestone(6, 0), 2833);
      expect(tribulationMilestone(6, 1), 3166);
      expect(tribulationMilestone(6, 2), 3500);
    });

    test('九转尊者劫里程碑', () {
      expect(tribulationMilestone(9, 0), 11333);
    });
  });

  group('passedTribulationCountForRealm / totalPassedTribulations', () {
    test('按最高 stage 记录统计', () {
      final records = [
        TribulationRecord(realmLevel: 6, stageIndex: 0),
        TribulationRecord(realmLevel: 7, stageIndex: 1),
        TribulationRecord(realmLevel: 8, stageIndex: 2),
        TribulationRecord(realmLevel: 9, stageIndex: 3),
      ];
      expect(passedTribulationCountForRealm(6, records), 0);
      expect(passedTribulationCountForRealm(7, records), 1);
      expect(passedTribulationCountForRealm(8, records), 2);
      expect(passedTribulationCountForRealm(9, records), 3);
      expect(totalPassedTribulations(records), 6);
    });

    test('无记录 → 0', () {
      expect(totalPassedTribulations([]), 0);
    });
  });

  group('dueTribulationStage', () {
    test('未到里程碑 → null', () {
      expect(
        dueTribulationStage(
            realmLevel: 6, currentCultivation: 2832, tribulations: []),
        isNull,
      );
    });

    test('达到 1/3 → stage 0', () {
      expect(
        dueTribulationStage(
            realmLevel: 6, currentCultivation: 2833, tribulations: []),
        0,
      );
    });

    test('已渡过 stage 0 后不再到期；达到 2/3 → stage 1', () {
      final records = [TribulationRecord(realmLevel: 6, stageIndex: 1)];
      expect(
        dueTribulationStage(
            realmLevel: 6, currentCultivation: 2833, tribulations: records),
        isNull,
      );
      expect(
        dueTribulationStage(
            realmLevel: 6, currentCultivation: 3166, tribulations: records),
        1,
      );
    });

    test('失败跌回里程碑以下 → null；修为再次达到 → 再次到期', () {
      // 首次达到 → 到期
      expect(
        dueTribulationStage(
            realmLevel: 6, currentCultivation: 3000, tribulations: []),
        0,
      );
      // 失败跌 1/3（跨度/3 = 333）→ 2667 < 2833 → 不再到期
      expect(
        dueTribulationStage(
            realmLevel: 6, currentCultivation: 2667, tribulations: []),
        isNull,
      );
      // 再次达到 → 再次到期
      expect(
        dueTribulationStage(
            realmLevel: 6, currentCultivation: 2833, tribulations: []),
        0,
      );
    });

    test('已完成（stage 3）→ null', () {
      final records = [TribulationRecord(realmLevel: 6, stageIndex: 3)];
      expect(
        dueTribulationStage(
            realmLevel: 6,
            currentCultivation: 99999,
            tribulations: records),
        isNull,
      );
    });

    test('九转尊者劫：达到 1/3 → stage 0', () {
      expect(
        dueTribulationStage(
            realmLevel: 9, currentCultivation: 11333, tribulations: []),
        0,
      );
      expect(
        dueTribulationStage(
            realmLevel: 9, currentCultivation: 11332, tribulations: []),
        isNull,
      );
    });
  });

  group('distanceToNextTribulation', () {
    test('无记录：距六转 1/3 差 2833', () {
      expect(
        distanceToNextTribulation(currentCultivation: 0, tribulations: []),
        2833,
      );
    });

    test('已过六转 1/3：下一里程碑为 2/3（3166）', () {
      final records = [TribulationRecord(realmLevel: 6, stageIndex: 1)];
      expect(
        distanceToNextTribulation(
            currentCultivation: 2900, tribulations: records),
        266,
      );
    });

    test('全部渡过 → 0', () {
      final records = [
        TribulationRecord(realmLevel: 6, stageIndex: 3),
        TribulationRecord(realmLevel: 7, stageIndex: 3),
        TribulationRecord(realmLevel: 8, stageIndex: 3),
        TribulationRecord(realmLevel: 9, stageIndex: 3),
      ];
      expect(
        distanceToNextTribulation(
            currentCultivation: 99999, tribulations: records),
        0,
      );
    });
  });
}
