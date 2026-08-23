import 'package:flutter_test/flutter_test.dart';
import 'package:sidequest/src/features/stats/logic/realm.dart';

void main() {
  group('getRealmProgress', () {
    test('凡人：0 修为，进度 0，下一境界为一转蛊师', () {
      final p = getRealmProgress(0);
      expect(p.name, '凡人');
      expect(p.level, 0);
      expect(p.currentThreshold, 0);
      expect(p.nextName, '一转蛊师');
      expect(p.nextThreshold, 100);
      expect(p.progress, 0.0);
      expect(p.isMaxRealm, isFalse);
    });

    test('负修为按凡人处理且进度为 0', () {
      final p = getRealmProgress(-10);
      expect(p.name, '凡人');
      expect(p.level, 0);
      expect(p.progress, 0.0);
    });

    test('99 修为仍是凡人，进度接近满', () {
      final p = getRealmProgress(99);
      expect(p.name, '凡人');
      expect(p.progress, closeTo(0.99, 0.0001));
    });

    test('100 修为进入一转蛊师，进度重新从 0 开始', () {
      final p = getRealmProgress(100);
      expect(p.name, '一转蛊师');
      expect(p.level, 1);
      expect(p.currentThreshold, 100);
      expect(p.nextName, '二转蛊师');
      expect(p.nextThreshold, 300);
      expect(p.progress, 0.0);
    });

    test('二转蛊师中途进度：450 修为', () {
      final p = getRealmProgress(450);
      expect(p.name, '二转蛊师');
      expect(p.level, 2);
      expect(p.progress, closeTo(0.5, 0.0001));
    });

    test('全部阈值映射到正确境界', () {
      final cases = <int, String>{
        0: '凡人',
        100: '一转蛊师',
        300: '二转蛊师',
        600: '三转蛊师',
        1000: '四转蛊师',
        1500: '五转蛊师',
        2500: '六转蛊仙',
        4000: '七转蛊仙',
        6000: '八转蛊仙',
        10000: '九转尊者',
      };
      cases.forEach((xp, name) {
        expect(getRealmProgress(xp).name, name, reason: '修为=$xp 应为 $name');
      });
    });

    test('九转尊者是最高境界，进度满', () {
      final p = getRealmProgress(10000);
      expect(p.name, '九转尊者');
      expect(p.level, 9);
      expect(p.isMaxRealm, isTrue);
      expect(p.nextName, isNull);
      expect(p.nextThreshold, isNull);
      expect(p.progress, 1.0);
    });

    test('超过最高阈值仍为九转尊者且满进度', () {
      final p = getRealmProgress(12345);
      expect(p.name, '九转尊者');
      expect(p.isMaxRealm, isTrue);
      expect(p.progress, 1.0);
    });
  });
}
