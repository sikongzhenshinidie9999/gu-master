import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:sidequest/src/features/cultivation/data/cultivation_session.dart';
import 'package:sidequest/src/features/cultivation/data/dao.dart';

void main() {
  // TypeAdapter 全局只注册一次
  Hive.registerAdapter(CultivationSessionAdapter()); // typeId 6

  late Directory tempDir;
  late Box<CultivationSession> sessionBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('session_storage_test_');
    Hive.init(tempDir.path);
    sessionBox = await Hive.openBox<CultivationSession>('sessions');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  CultivationSession makeSession(String id,
      {String subject = '英语', int minutes = 25}) {
    return CultivationSession(
      id: id,
      startTime: DateTime(2026, 8, 24, 9, 0),
      endTime: DateTime(2026, 8, 24, 9, minutes),
      plannedDurationMinutes: minutes,
      actualDurationMinutes: minutes,
      subject: subject,
      category: CultivationSessionCategory.shen.index,
      status: CultivationSessionStatus.completed.index,
      xpEarned: minutes * 2,
      daoTraceKind: DaoKind.zhi.index,
      daoTraceAmount: minutes,
      realmExpEarned: minutes,
    );
  }

  test('Hive 可以打开 sessions box', () {
    expect(sessionBox, isNotNull);
    expect(sessionBox.isOpen, isTrue);
  });

  test('add 后 get 字段一致', () async {
    final s = makeSession('s1');
    final key = await sessionBox.add(s);
    final stored = sessionBox.get(key);
    expect(stored, isNotNull);
    expect(stored!.id, 's1');
    expect(stored.subject, '英语');
    expect(stored.category, CultivationSessionCategory.shen.index);
    expect(stored.status, CultivationSessionStatus.completed.index);
    expect(stored.plannedDurationMinutes, 25);
    expect(stored.actualDurationMinutes, 25);
    expect(stored.startTime, DateTime(2026, 8, 24, 9, 0));
    expect(stored.endTime, DateTime(2026, 8, 24, 9, 25));
    expect(stored.xpEarned, 50);
    expect(stored.daoTraceKind, DaoKind.zhi.index);
    expect(stored.daoTraceAmount, 25);
    expect(stored.realmExpEarned, 25);
  });

  test('多条 session 可以保存', () async {
    await sessionBox.add(makeSession('s1'));
    await sessionBox.add(makeSession('s2', subject: '数学', minutes: 45));
    expect(sessionBox.length, 2);
    final ids = sessionBox.values.map((s) => s.id).toList();
    expect(ids, containsAll(['s1', 's2']));
    final math = sessionBox.values.firstWhere((s) => s.id == 's2');
    expect(math.subject, '数学');
    expect(math.actualDurationMinutes, 45);
  });

  test('删除 session 后不存在', () async {
    final key = await sessionBox.add(makeSession('s1'));
    expect(sessionBox.containsKey(key), isTrue);
    await sessionBox.delete(key);
    expect(sessionBox.containsKey(key), isFalse);
    expect(sessionBox.length, 0);
  });
}
