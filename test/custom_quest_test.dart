import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:sidequest/src/features/quests/data/quest_model.dart';
import 'package:sidequest/src/features/quests/logic/quest_provider.dart';

void main() {
  // TypeAdapter 全局只注册一次
  Hive.registerAdapter(QuestModelAdapter());

  late Directory tempDir;
  late Box<QuestModel> questBox;
  late Box statsBox;
  late Box settingsBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('custom_quest_test_');
    Hive.init(tempDir.path);
    questBox = await Hive.openBox<QuestModel>('quests');
    statsBox = await Hive.openBox('stats');
    settingsBox = await Hive.openBox('settings');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  QuestNotifier newNotifier() => QuestNotifier(questBox, statsBox, settingsBox);

  test('创建自定义任务：id 以 custom_ 开头并保存到 quests Box', () {
    final notifier = newNotifier();
    notifier.createCustomQuest(
      title: '背英语单词 30 分钟',
      description: '背单词并默写',
      category: '悟道',
      tier: 2,
    );

    final custom = notifier.state.availableQuests.last;
    expect(custom.id.startsWith('custom_'), isTrue);
    expect(custom.title, '背英语单词 30 分钟');
    expect(custom.description, '背单词并默写');
    expect(custom.category, '悟道');
    expect(custom.tier, 2);

    // 已写入 quests Box
    final inBox = questBox.values.where((q) => q.id == custom.id).toList();
    expect(inBox.length, 1);
    // 出现在 availableQuests
    expect(notifier.state.availableQuests, contains(custom));
    // 不影响 active / completed
    expect(notifier.state.activeQuests, isEmpty);
    expect(notifier.state.completedQuests, isEmpty);
  });

  test('系统任务 id 是 UUID，不会被识别为自定义任务', () {
    final notifier = newNotifier();
    // 全新盒子默认生成 6 个系统任务
    expect(notifier.state.availableQuests.length, 6);
    for (final q in notifier.state.availableQuests) {
      expect(q.id.startsWith('custom_'), isFalse);
    }
  });

  test('每日刷新保留自定义任务，且系统任务仍为 6 个', () async {
    final first = newNotifier();
    first.createCustomQuest(
      title: '自定义任务',
      description: '不会被刷新删除',
      category: '炼神',
      tier: 1,
    );
    final customId = first.state.availableQuests.last.id;
    expect(customId.startsWith('custom_'), isTrue);

    // 模拟新的一天：把 lastRefresh 改到两天前，再重建 Notifier 触发每日刷新
    await statsBox.put('lastRefresh', DateTime.now().subtract(const Duration(days: 2)));

    final second = newNotifier();
    final customs =
        second.state.availableQuests.where((q) => q.id.startsWith('custom_')).toList();
    final system =
        second.state.availableQuests.where((q) => !q.id.startsWith('custom_')).toList();

    expect(customs.length, 1);
    expect(customs.first.id, customId);
    expect(system.length, 6);
    expect(second.state.availableQuests.length, 7);
  });

  test('自定义任务可接受、完成并获得修为', () {
    final notifier = newNotifier();
    notifier.createCustomQuest(
      title: '打坐',
      description: '静坐十分钟',
      category: '炼神',
      tier: 2,
    );
    final custom = notifier.state.availableQuests.last;

    notifier.acceptQuest(custom);
    expect(notifier.state.availableQuests, isNot(contains(custom)));
    expect(notifier.state.activeQuests, contains(custom));

    notifier.completeQuest(custom);
    expect(notifier.state.activeQuests, isNot(contains(custom)));
    expect(notifier.state.completedQuests, contains(custom));
    expect(notifier.state.totalXp, 25); // 二阶 → 25 修为
    expect(statsBox.get('totalXp'), 25);
  });

  group('每日自定义任务刷新', () {
    test('创建自定义任务会保存模板', () {
      final notifier = newNotifier();
      notifier.createCustomQuest(
        title: '背英语单词 30 分钟',
        description: '背单词并默写',
        category: '炼神',
        tier: 2,
      );

      final templates = statsBox.get('customQuestTemplates') as List;
      expect(templates.length, 1);
      final t = Map<String, dynamic>.from(templates.first as Map);
      expect(t['title'], '背英语单词 30 分钟');
      expect(t['description'], '背单词并默写');
      expect(t['category'], '炼神');
      expect(t['tier'], 2);
    });

    test('同一天重复创建相同任务不会重复生成模板或实例', () {
      final notifier = newNotifier();
      notifier.createCustomQuest(title: 'X', description: 'x', category: '炼体', tier: 1);
      notifier.createCustomQuest(title: 'X', description: 'x', category: '炼体', tier: 1);

      final templates = statsBox.get('customQuestTemplates') as List;
      expect(templates.length, 1);
      final customs = notifier.state.availableQuests.where((q) => q.id.startsWith('custom_')).toList();
      expect(customs.length, 1);
      expect(questBox.values.where((q) => q.id.startsWith('custom_')).length, 1);
    });

    test('同一天 Shuffle 不会复制自定义任务', () {
      final notifier = newNotifier();
      notifier.createCustomQuest(title: 'Y', description: 'y', category: '悟道', tier: 2);
      expect(notifier.state.canShuffle, isTrue);

      notifier.shuffleQuests();

      final customs = notifier.state.availableQuests.where((q) => q.id.startsWith('custom_')).toList();
      expect(customs.length, 1);
      final system = notifier.state.availableQuests.where((q) => !q.id.startsWith('custom_')).toList();
      expect(system.length, 6);
      expect(questBox.values.where((q) => q.id.startsWith('custom_')).length, 1);
    });

    test('模拟第二天：旧未完成实例被删除并生成新实例', () async {
      await statsBox.put('customQuestTemplates', [
        {'title': '背单词', 'description': '背 30 分钟', 'category': '炼神', 'tier': 2},
      ]);
      final oldQuest = QuestModel(
        id: 'custom_old',
        title: '背单词',
        description: '背 30 分钟',
        category: '炼神',
        tier: 2,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await questBox.add(oldQuest);
      await statsBox.put('lastRefresh', DateTime.now().subtract(const Duration(days: 2)));

      final notifier = QuestNotifier(questBox, statsBox, settingsBox);
      final customs = notifier.state.availableQuests.where((q) => q.id.startsWith('custom_')).toList();
      expect(customs.length, 1);

      final today = customs.first;
      expect(today.id, isNot('custom_old'));
      expect(today.acceptedAt, isNull);
      expect(today.isCompleted, isFalse);
      expect(today.isFailed, isFalse);
      final now = DateTime.now();
      expect(today.createdAt.year, now.year);
      expect(today.createdAt.month, now.month);
      expect(today.createdAt.day, now.day);

      expect(questBox.values.where((q) => q.id == 'custom_old'), isEmpty);
    });

    test('昨日已完成任务：completed 历史保留，今天仍生成新实例', () async {
      await statsBox.put('customQuestTemplates', [
        {'title': '冥想', 'description': '打坐', 'category': '炼神', 'tier': 1},
      ]);
      final doneOld = QuestModel(
        id: 'custom_old_done',
        title: '冥想',
        description: '打坐',
        category: '炼神',
        tier: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        isCompleted: true,
      );
      await questBox.add(doneOld);
      await statsBox.put('lastRefresh', DateTime.now().subtract(const Duration(days: 2)));

      final notifier = QuestNotifier(questBox, statsBox, settingsBox);
      expect(questBox.values.where((q) => q.id == 'custom_old_done').length, 1);
      expect(notifier.state.completedQuests.map((q) => q.id), contains('custom_old_done'));
      final customs = notifier.state.availableQuests.where((q) => q.id.startsWith('custom_')).toList();
      expect(customs.length, 1);
      expect(customs.first.id, isNot('custom_old_done'));
    });

    test('昨日 active 任务不再进入 active，今天生成新的 available 实例', () async {
      await statsBox.put('customQuestTemplates', [
        {'title': '炼体', 'description': '俯卧撑', 'category': '炼体', 'tier': 1},
      ]);
      final activeOld = QuestModel(
        id: 'custom_old_active',
        title: '炼体',
        description: '俯卧撑',
        category: '炼体',
        tier: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        acceptedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await questBox.add(activeOld);
      await statsBox.put('lastRefresh', DateTime.now().subtract(const Duration(days: 2)));

      final notifier = QuestNotifier(questBox, statsBox, settingsBox);
      expect(notifier.state.activeQuests.where((q) => q.id == 'custom_old_active'), isEmpty);
      expect(questBox.values.where((q) => q.id == 'custom_old_active'), isEmpty);
      final customs = notifier.state.availableQuests.where((q) => q.id.startsWith('custom_')).toList();
      expect(customs.length, 1);
    });

    test('昨日 failed 任务被删除，今天生成新的 available 实例', () async {
      await statsBox.put('customQuestTemplates', [
        {'title': '杂务', 'description': '打扫', 'category': '杂务', 'tier': 1},
      ]);
      final failedOld = QuestModel(
        id: 'custom_old_failed',
        title: '杂务',
        description: '打扫',
        category: '杂务',
        tier: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        isFailed: true,
      );
      await questBox.add(failedOld);
      await statsBox.put('lastRefresh', DateTime.now().subtract(const Duration(days: 2)));

      final notifier = QuestNotifier(questBox, statsBox, settingsBox);
      expect(questBox.values.where((q) => q.id == 'custom_old_failed'), isEmpty);
      final customs = notifier.state.availableQuests.where((q) => q.id.startsWith('custom_')).toList();
      expect(customs.length, 1);
    });

    test('多个模板：每个模板每天各只生成一个实例', () async {
      await statsBox.put('customQuestTemplates', [
        {'title': 'A', 'description': 'a', 'category': '炼体', 'tier': 1},
        {'title': 'B', 'description': 'b', 'category': '悟道', 'tier': 2},
      ]);
      await statsBox.put('lastRefresh', DateTime.now().subtract(const Duration(days: 2)));

      final notifier = QuestNotifier(questBox, statsBox, settingsBox);
      final customs = notifier.state.availableQuests.where((q) => q.id.startsWith('custom_')).toList();
      expect(customs.length, 2);
      expect(customs.map((q) => q.title).toSet(), {'A', 'B'});
      expect(questBox.values.where((q) => q.id.startsWith('custom_')).length, 2);
    });

    test('连续模拟多天不会出现实例爆炸', () async {
      await statsBox.put('customQuestTemplates', [
        {'title': 'T', 'description': 'D', 'category': '炼神', 'tier': 1},
      ]);
      final old = QuestModel(
        id: 'custom_day1',
        title: 'T',
        description: 'D',
        category: '炼神',
        tier: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await questBox.add(old);
      await statsBox.put('lastRefresh', DateTime.now().subtract(const Duration(days: 2)));

      final day2 = QuestNotifier(questBox, statsBox, settingsBox);
      expect(questBox.values.where((q) => q.id.startsWith('custom_')).length, 1);
      expect(day2.state.availableQuests.where((q) => q.id.startsWith('custom_')).length, 1);

      for (final q in questBox.values.where((q) => q.id.startsWith('custom_')).toList()) {
        await q.delete();
      }
      await statsBox.put('lastRefresh', DateTime.now().subtract(const Duration(days: 2)));

      final day3 = QuestNotifier(questBox, statsBox, settingsBox);
      expect(questBox.values.where((q) => q.id.startsWith('custom_')).length, 1);
      expect(day3.state.availableQuests.where((q) => q.id.startsWith('custom_')).length, 1);
    });

    test('旧版本 custom_ 任务可回填模板且不丢失', () async {
      final legacy = QuestModel(
        id: 'custom_legacy',
        title: '旧任务',
        description: '旧描述',
        category: '炼气',
        tier: 3,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await questBox.add(legacy);
      await statsBox.put('lastRefresh', DateTime.now().subtract(const Duration(days: 2)));

      final notifier = QuestNotifier(questBox, statsBox, settingsBox);

      final templates = statsBox.get('customQuestTemplates') as List;
      expect(templates.length, 1);
      final t = Map<String, dynamic>.from(templates.first as Map);
      expect(t['title'], '旧任务');
      expect(t['category'], '炼气');
      expect(t['tier'], 3);

      final customs = notifier.state.availableQuests.where((q) => q.id.startsWith('custom_')).toList();
      expect(customs.length, 1);
      expect(customs.first.title, '旧任务');
      expect(questBox.values.where((q) => q.id == 'custom_legacy'), isEmpty);
    });

    test('系统任务保持 tier1×2 / tier2×2 / tier3×2', () {
      final notifier = newNotifier();
      final system = notifier.state.availableQuests.where((q) => !q.id.startsWith('custom_')).toList();
      expect(system.length, 6);
      expect(system.where((q) => q.tier == 1).length, 2);
      expect(system.where((q) => q.tier == 2).length, 2);
      expect(system.where((q) => q.tier == 3).length, 2);
    });
  });

  group('任务手动删除', () {
    test('删除 available 系统任务：Hive 与 UI 移除，刷新后系统任务仍 6 个', () {
      final notifier = newNotifier();
      final system = notifier.state.availableQuests
          .firstWhere((q) => !q.id.startsWith('custom_'));
      final systemId = system.id;

      notifier.deleteQuest(system);

      expect(questBox.values.where((q) => q.id == systemId), isEmpty);
      expect(notifier.state.availableQuests.where((q) => q.id == systemId), isEmpty);
      expect(notifier.state.availableQuests.length, 5);

      notifier.shuffleQuests();
      final systemAfter =
          notifier.state.availableQuests.where((q) => !q.id.startsWith('custom_')).toList();
      expect(systemAfter.length, 6);
    });

    test('删除 active 自定义任务：Hive 删除、active 消失、模板仍在', () {
      final notifier = newNotifier();
      notifier.createCustomQuest(title: '冥想', description: '打坐', category: '炼神', tier: 1);
      final custom = notifier.state.availableQuests.last;
      final customId = custom.id;
      notifier.acceptQuest(custom);

      notifier.deleteQuest(custom);

      expect(questBox.values.where((q) => q.id == customId), isEmpty);
      expect(notifier.state.activeQuests.where((q) => q.id == customId), isEmpty);
      final templates = statsBox.get('customQuestTemplates') as List;
      expect(templates.length, 1);
    });

    test('删除 completed 任务：Hive 删除、completed 消失', () {
      final notifier = newNotifier();
      notifier.createCustomQuest(title: '打坐', description: '十分钟', category: '炼神', tier: 1);
      final custom = notifier.state.availableQuests.last;
      final customId = custom.id;
      notifier.acceptQuest(custom);
      notifier.completeQuest(custom);
      expect(notifier.state.completedQuests.map((q) => q.id), contains(customId));

      notifier.deleteQuest(custom);

      expect(questBox.values.where((q) => q.id == customId), isEmpty);
      expect(notifier.state.completedQuests.where((q) => q.id == customId), isEmpty);
    });

    test('删除当天自定义任务：今日消失、模板仍在、同日 Shuffle 不复活', () {
      final notifier = newNotifier();
      notifier.createCustomQuest(title: '背单词', description: '30 分钟', category: '炼神', tier: 2);
      final custom = notifier.state.availableQuests.last;
      final customId = custom.id;

      notifier.deleteQuest(custom);

      expect(notifier.state.availableQuests.where((q) => q.id == customId), isEmpty);
      expect(questBox.values.where((q) => q.id == customId), isEmpty);
      final templates = statsBox.get('customQuestTemplates') as List;
      expect(templates.length, 1);

      expect(notifier.state.canShuffle, isTrue);
      notifier.shuffleQuests();
      final customsAfter =
          notifier.state.availableQuests.where((q) => q.id.startsWith('custom_')).toList();
      expect(customsAfter, isEmpty);
      expect(questBox.values.where((q) => q.id.startsWith('custom_')).length, 0);
    });

    test('删除当天自定义任务后，第二天按模板重新生成新实例', () async {
      final notifier = newNotifier();
      notifier.createCustomQuest(title: '晨练', description: '拉伸', category: '炼体', tier: 1);
      final custom = notifier.state.availableQuests.last;
      final oldId = custom.id;
      notifier.deleteQuest(custom);

      await statsBox.put('lastRefresh', DateTime.now().subtract(const Duration(days: 2)));
      final notifier2 = QuestNotifier(questBox, statsBox, settingsBox);

      final customs = notifier2.state.availableQuests
          .where((q) => q.id.startsWith('custom_')).toList();
      expect(customs.length, 1);
      final today = customs.first;
      expect(today.id, isNot(oldId));
      final now = DateTime.now();
      expect(today.createdAt.year, now.year);
      expect(today.createdAt.month, now.month);
      expect(today.createdAt.day, now.day);
      expect(today.acceptedAt, isNull);
      expect(today.isCompleted, isFalse);
      expect(today.isFailed, isFalse);
      expect(today.title, '晨练');
    });

    test('多个自定义任务分别删除：只影响被删者，其他模板正常生成', () {
      final notifier = newNotifier();
      notifier.createCustomQuest(title: 'A', description: 'a', category: '炼体', tier: 1);
      notifier.createCustomQuest(title: 'B', description: 'b', category: '悟道', tier: 2);
      final customs = notifier.state.availableQuests
          .where((q) => q.id.startsWith('custom_')).toList();
      expect(customs.length, 2);

      final a = customs.firstWhere((q) => q.title == 'A');
      notifier.deleteQuest(a);

      expect(questBox.values.where((q) => q.id == a.id), isEmpty);
      final remaining = notifier.state.availableQuests
          .where((q) => q.id.startsWith('custom_')).toList();
      expect(remaining.length, 1);
      expect(remaining.first.title, 'B');
      final templates = statsBox.get('customQuestTemplates') as List;
      expect(templates.length, 2);
    });

    test('删除系统任务不永久影响任务池', () async {
      final notifier = newNotifier();
      final system = notifier.state.availableQuests
          .firstWhere((q) => !q.id.startsWith('custom_'));
      final deletedId = system.id;
      notifier.deleteQuest(system);

      // 模拟连续 3 天刷新：每次都正常生成 6 个系统任务，且无任何排除记录
      for (var i = 0; i < 3; i++) {
        await statsBox.put('lastRefresh', DateTime.now().subtract(const Duration(days: 2)));
        final refreshed = QuestNotifier(questBox, statsBox, settingsBox);
        final systemAfter = refreshed.state.availableQuests
            .where((q) => !q.id.startsWith('custom_')).toList();
        expect(systemAfter.length, 6);
        expect(systemAfter.any((q) => q.id == deletedId), isFalse);
      }

      // 删除没有写入任何排除标记：模板键保持为空，任务池（硬编码）未受影响
      expect(statsBox.get('customQuestTemplates'), isNull);
    });
  });
}
