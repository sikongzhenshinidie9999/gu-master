import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:sidequest/src/features/cultivation/data/gu_material_definition.dart';
import 'package:sidequest/src/features/cultivation/logic/material_drop_service.dart';

void main() {
  group('rollMaterialDrop', () {
    test('Random 可以注入', () {
      final result = rollMaterialDrop(currentTurn: 1, random: Random(42));
      // 注入 Random 后正常返回（不抛异常）
      expect(result, anyOf(isNull, isA<String>()));
    });

    test('返回结果一定来自定义表', () {
      final ids = kGuMaterialDefinitions.map((d) => d.materialId).toSet();
      for (var seed = 0; seed < 100; seed++) {
        final r = rollMaterialDrop(currentTurn: 5, random: Random(seed));
        if (r != null) expect(ids, contains(r));
      }
    });

    test('当前转数过滤正确', () {
      // 转数 1：只允许青铜沙 / 玄铁粉（血莲瓣 3+、九转精魄 7+ 不应出现）
      final ids1 = kGuMaterialDefinitions
          .where((d) => d.minTurn <= 1 && d.maxTurn >= 1)
          .map((d) => d.materialId)
          .toSet();
      for (var seed = 0; seed < 100; seed++) {
        final r = rollMaterialDrop(currentTurn: 1, random: Random(seed));
        if (r != null) expect(ids1, contains(r));
      }

      // 转数 7：四种材料都允许
      final ids7 = kGuMaterialDefinitions
          .where((d) => d.minTurn <= 7 && d.maxTurn >= 7)
          .map((d) => d.materialId)
          .toSet();
      for (var seed = 0; seed < 100; seed++) {
        final r = rollMaterialDrop(currentTurn: 7, random: Random(seed));
        if (r != null) expect(ids7, contains(r));
      }
    });

    test('权重边界正确（高权重材料出现更多）', () {
      var bronze = 0;
      var spirit = 0;
      for (var seed = 0; seed < 2000; seed++) {
        final r = rollMaterialDrop(currentTurn: 9, random: Random(seed));
        if (r == 'bronze_sand') bronze++;
        if (r == 'nine_turn_spirit') spirit++;
      }
      expect(bronze, greaterThan(spirit));
    });

    test('没有合法材料时返回 null', () {
      final r = rollMaterialDrop(
        currentTurn: 5,
        random: Random(1),
        definitions: const [],
      );
      expect(r, isNull);
    });
  });
}
