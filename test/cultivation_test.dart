import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:sidequest/src/features/cultivation/data/dao.dart';
import 'package:sidequest/src/features/cultivation/data/dao_zhu.dart';
import 'package:sidequest/src/features/cultivation/data/gu_insect.dart';
import 'package:sidequest/src/features/cultivation/data/gu_material.dart';
import 'package:sidequest/src/features/cultivation/data/faction_level.dart';
import 'package:sidequest/src/features/cultivation/data/player_profile.dart';
import 'package:sidequest/src/features/cultivation/data/tribulation_record.dart';
import 'package:sidequest/src/features/cultivation/logic/cultivation_provider.dart';
import 'package:sidequest/src/features/cultivation/logic/faction_realm.dart';
import 'package:sidequest/src/features/cultivation/logic/refining_config.dart';
import 'package:sidequest/src/features/cultivation/logic/reward_calculator.dart';
import 'package:sidequest/src/features/cultivation/logic/reward_config.dart';
import 'package:sidequest/src/features/quests/logic/quest_provider.dart';
import 'package:sidequest/src/features/quests/data/quest_model.dart';

void main() {
  // TypeAdapter 全局只注册一次
  Hive.registerAdapter(QuestModelAdapter()); // typeId 0
  Hive.registerAdapter(PlayerProfileAdapter()); // typeId 1
  Hive.registerAdapter(TribulationRecordAdapter()); // typeId 2
  Hive.registerAdapter(GuInsectAdapter()); // typeId 3
  Hive.registerAdapter(GuMaterialAdapter()); // typeId 4
  Hive.registerAdapter(DaoZhuStateAdapter()); // typeId 5

  late Directory tempDir;
  late Box<PlayerProfile> cultivationBox;
  late Box<QuestModel> questBox;
  late Box statsBox;
  late Box settingsBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cultivation_test_');
    Hive.init(tempDir.path);
    cultivationBox = await Hive.openBox<PlayerProfile>('cultivation');
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

  test('新玩家没有 cultivation profile 时可正确初始化', () {
    final notifier = CultivationNotifier(cultivationBox, statsBox);
    expect(notifier.state.profile.totalXp, 0);
    expect(notifier.state.profile.currentCultivation, 0);
    expect(cultivationBox.values.length, 1);
  });

  test('stats.totalXp=1000 时初始化 totalXp 与 currentCultivation 均为 1000', () async {
    await statsBox.put('totalXp', 1000);
    final notifier = CultivationNotifier(cultivationBox, statsBox);
    expect(notifier.state.profile.totalXp, 1000);
    expect(notifier.state.profile.currentCultivation, 1000);
  });

  test('已存在 cultivation profile 时不会被重新初始化覆盖', () async {
    final existing = PlayerProfile(totalXp: 500, currentCultivation: 400);
    await cultivationBox.add(existing);

    await statsBox.put('totalXp', 1000); // 即使 stats 有更高值也不覆盖
    final notifier = CultivationNotifier(cultivationBox, statsBox);
    expect(notifier.state.profile.totalXp, 500);
    expect(notifier.state.profile.currentCultivation, 400);
  });

  test('PlayerProfile 可正确写入 Hive', () async {
    final notifier = CultivationNotifier(cultivationBox, statsBox);
    final profile = notifier.state.profile;
    profile.totalXp = 1234;
    profile.currentCultivation = 1200;
    profile.daoTraces[0] = 10; // DaoKind.li
    profile.factionLevels[1] = 2; // Faction.zhi -> FactionLevel.grandmaster
    profile.tribulations.add(
        TribulationRecord(realmLevel: 6, stageIndex: 1, failCount: 2));
    profile.guInsects.add(GuInsect(
      id: 'g1',
      turn: 2,
      refinedDaoLevel: 3,
      definitionId: 'bronze_beetle',
      faction: Faction.li.index,
      quality: 0,
    ));
    profile.guMaterials.add(GuMaterial(materialId: 'bronze_sand', quantity: 5));
    notifier.saveProfile(profile);

    final stored = cultivationBox.values.first;
    expect(stored.totalXp, 1234);
    expect(stored.currentCultivation, 1200);
    expect(stored.daoTraces[0], 10);
    expect(stored.factionLevels[1], 2);
    expect(stored.tribulations.length, 1);
    expect(stored.tribulations.first.stageIndex, 1);
    expect(stored.tribulations.first.failCount, 2);
    expect(stored.guInsects.length, 1);
    expect(stored.guInsects.first.turn, 2);
    expect(stored.guMaterials.length, 1);
    expect(stored.guMaterials.first.quantity, 5);
  });

  test('PlayerProfile 可从 Hive 正确读取（重建后不覆盖）', () async {
    final first = CultivationNotifier(cultivationBox, statsBox);
    final profile = first.state.profile;
    profile.totalXp = 888;
    profile.currentCultivation = 777;
    first.saveProfile(profile);

    final second = CultivationNotifier(cultivationBox, statsBox);
    expect(second.state.profile.totalXp, 888);
    expect(second.state.profile.currentCultivation, 777);
    expect(cultivationBox.values.length, 1);
  });

  test('QuestModel typeId 0 完全不受影响', () async {
    final questBox = await Hive.openBox<QuestModel>('quests');
    final q = QuestModel(
      id: 'q1',
      title: '测试任务',
      description: '描述',
      tier: 2,
      createdAt: DateTime.now(),
      category: '炼体',
    );
    await questBox.add(q);
    expect(questBox.values.length, 1);
    expect(questBox.values.first.id, 'q1');
    expect(questBox.values.first.tier, 2);
    await questBox.delete(q.key);
    expect(questBox.values.length, 0);
  });

  group('完成任务 → 道痕', () {
    QuestNotifier newWiredQuestNotifier(CultivationNotifier cult) =>
        QuestNotifier(questBox, statsBox, settingsBox,
            onQuestCompleted: cult.applyQuestCompletedRewards);

    test('完成任务 → 道痕写入 PlayerProfile，XP 与以前一致', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final quests = newWiredQuestNotifier(cult);
      quests.createCustomQuest(
          title: '炼体修炼', description: '俯卧撑', category: '炼体', tier: 1);
      final q = quests.state.availableQuests.last;
      quests.acceptQuest(q);

      final xpBefore = quests.state.totalXp;
      final daoBefore = cult.state.profile.daoTraces[DaoKind.li.index] ?? 0;
      final expBefore =
          cult.state.profile.factionRealmExp[Faction.li.daoKind.index] ?? 0;

      quests.completeQuest(q);

      expect(quests.state.totalXp, xpBefore + 10); // tier1 → 10 修为，与以前一致
      // 道痕与感悟分别写入两个独立 Map，各自累加
      expect(cult.state.profile.daoTraces[DaoKind.li.index], daoBefore + 5);
      expect(cult.state.profile.factionRealmExp[Faction.li.daoKind.index],
          expBefore + kBasicRealmExpReward);
    });

    test('同一个任务不能重复领取道痕奖励', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final quests = newWiredQuestNotifier(cult);
      quests.createCustomQuest(
          title: '炼神修炼', description: '打坐', category: '炼神', tier: 2);
      final q = quests.state.availableQuests.last;
      quests.acceptQuest(q);

      quests.completeQuest(q);
      final daoAfter1 = cult.state.profile.daoTraces[DaoKind.zhi.index] ?? 0;
      final xpAfter1 = quests.state.totalXp;

      quests.completeQuest(q); // 再次完成：不得重复发奖
      expect(cult.state.profile.daoTraces[DaoKind.zhi.index], daoAfter1);
      expect(quests.state.totalXp, xpAfter1);
    });

    test('老用户已有 PlayerProfile 时，道痕不会被初始化清零', () async {
      final existing = PlayerProfile(totalXp: 1000, currentCultivation: 900);
      existing.daoTraces[DaoKind.lian.index] = 66;
      await cultivationBox.add(existing);

      final cult = CultivationNotifier(cultivationBox, statsBox);
      expect(cult.state.profile.daoTraces[DaoKind.lian.index], 66);

      final quests = newWiredQuestNotifier(cult);
      quests.createCustomQuest(
          title: '炼蛊', description: '炼蛊', category: '炼蛊', tier: 1);
      final q = quests.state.availableQuests.last;
      quests.acceptQuest(q);
      quests.completeQuest(q);
      expect(cult.state.profile.daoTraces[DaoKind.lian.index], 66 + 5);
    });

    test('完成任务 → 道痕与感悟独立累加，互不换算', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final quests = newWiredQuestNotifier(cult);
      quests.createCustomQuest(
          title: '炼蛊', description: '炼蛊', category: '炼蛊', tier: 1);
      final q = quests.state.availableQuests.last;
      quests.acceptQuest(q);
      quests.completeQuest(q);

      final dao = cult.state.profile.daoTraces[DaoKind.lian.index] ?? 0;
      final exp =
          cult.state.profile.factionRealmExp[Faction.lian.daoKind.index] ?? 0;
      expect(dao, greaterThan(0));
      expect(exp, greaterThan(0));

      // 只增加感悟 → 境界由感悟推进，道痕不受影响
      expect(getFactionRealmProgress(Faction.lian, exp + 99999).level,
          FactionLevel.supremeGrandmaster);
      expect(cult.state.profile.daoTraces[DaoKind.lian.index], dao);

      // 道痕再多也不影响境界：境界只看 factionRealmExp
      expect(getFactionRealmProgress(Faction.lian, exp).level,
          FactionLevel.ordinary);
      expect(getFactionRealmProgress(Faction.lian, dao).level,
          FactionLevel.ordinary);
    });

    test('旧 PlayerProfile 无 factionRealmExp 时兼容（感悟空、道痕保留）', () async {
      // 模拟旧版档案：未设置 factionRealmExp（默认空），只带道痕
      final legacy = PlayerProfile(totalXp: 1000, currentCultivation: 900);
      legacy.daoTraces[DaoKind.zhi.index] = 777;
      await cultivationBox.add(legacy);

      final notifier = CultivationNotifier(cultivationBox, statsBox);
      final profile = notifier.state.profile;
      // 道痕完整保留
      expect(profile.daoTraces[DaoKind.zhi.index], 777);
      // 感悟为空（默认 {}），不会由道痕转换而来
      expect(profile.factionRealmExp, isEmpty);
      // 境界回到普通（预期行为）
      final realm = getFactionRealmProgress(
          Faction.zhi, profile.factionRealmExp[Faction.zhi.daoKind.index] ?? 0);
      expect(realm.level, FactionLevel.ordinary);
    });
  });

  group('蛊材 / 蛊虫 Hive 序列化', () {
    test('GuMaterial materialId 与 quantity 正确写读', () async {
      final profile = PlayerProfile();
      profile.guMaterials.add(
          GuMaterial(materialId: 'bronze_sand', quantity: 5));
      await cultivationBox.add(profile);
      final stored = cultivationBox.values.first;
      expect(stored.guMaterials.length, 1);
      expect(stored.guMaterials.first.materialId, 'bronze_sand');
      expect(stored.guMaterials.first.quantity, 5);
    });

    test('GuInsect 原字段 + 新字段正确写读', () async {
      final profile = PlayerProfile();
      profile.guInsects.add(GuInsect(
        id: 'g1',
        turn: 3,
        refinedDaoLevel: 2,
        definitionId: 'iron_centipede',
        faction: Faction.lian.index,
        quality: 1,
      ));
      await cultivationBox.add(profile);
      final stored = cultivationBox.values.first;
      final insect = stored.guInsects.first;
      expect(insect.id, 'g1');
      expect(insect.turn, 3);
      expect(insect.refinedDaoLevel, 2);
      expect(insect.definitionId, 'iron_centipede');
      expect(insect.faction, Faction.lian.index);
      expect(insect.quality, 1);
    });
  });

  group('任务完成蛊材掉落', () {
    QuestNotifier wired(CultivationNotifier cult) => QuestNotifier(
        questBox, statsBox, settingsBox,
        onQuestCompleted: cult.applyQuestCompletedRewards);

    test('完成任务可获得材料', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final quests = wired(cult);
      quests.createCustomQuest(
          title: '杂务', description: '扫地', category: '杂务', tier: 1);
      final q = quests.state.availableQuests.last;
      quests.acceptQuest(q);
      quests.completeQuest(q);
      // 默认转数 1 下必有合法材料 → 一定掉落
      expect(cult.state.profile.guMaterials, isNotEmpty);
    });

    test('相同 materialId 正确堆叠', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final quests = wired(cult);
      for (var i = 0; i < 2; i++) {
        quests.createCustomQuest(
            title: '杂务$i', description: 'd', category: '杂务', tier: 1);
        final q = quests.state.availableQuests.last;
        quests.acceptQuest(q);
        cult.applyQuestCompletedRewards(q, random: _FixedRandom(0.0));
      }
      final bronze = cult.state.profile.guMaterials
          .where((m) => m.materialId == 'bronze_sand')
          .toList();
      expect(bronze.length, 1);
      expect(bronze.first.quantity, 2);
    });

    test('每日上限生效', () async {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      await statsBox.put('lastMaterialDropDay', DateTime.now());
      await statsBox.put('dailyMaterialDropCount', kMaxDailyMaterialDrops);
      final quests = wired(cult);
      quests.createCustomQuest(
          title: '杂务', description: 'd', category: '杂务', tier: 1);
      final q = quests.state.availableQuests.last;
      quests.acceptQuest(q);
      cult.applyQuestCompletedRewards(q, random: _FixedRandom(0.0));
      expect(cult.state.profile.guMaterials, isEmpty);
    });

    test('日期变化重置计数', () async {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      await statsBox.put('lastMaterialDropDay',
          DateTime.now().subtract(const Duration(days: 1)));
      await statsBox.put('dailyMaterialDropCount', kMaxDailyMaterialDrops);
      final quests = wired(cult);
      quests.createCustomQuest(
          title: '杂务', description: 'd', category: '杂务', tier: 1);
      final q = quests.state.availableQuests.last;
      quests.acceptQuest(q);
      cult.applyQuestCompletedRewards(q, random: _FixedRandom(0.0));
      expect(cult.state.profile.guMaterials, isNotEmpty);
      expect(statsBox.get('dailyMaterialDropCount'), 1);
    });

    test('未掉落不增加计数', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final quests = wired(cult);
      quests.createCustomQuest(
          title: '杂务', description: 'd', category: '杂务', tier: 1);
      final q = quests.state.availableQuests.last;
      quests.acceptQuest(q);
      // 转数越界 → 无合法材料 → 不掉落、计数保持 0
      cult.applyQuestCompletedRewards(q,
          random: _FixedRandom(0.0), materialDropTurn: 99);
      expect(cult.state.profile.guMaterials, isEmpty);
      expect(statsBox.get('dailyMaterialDropCount'), 0);
    });

    test('重复 completeQuest 不重复掉落', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      final quests = wired(cult);
      quests.createCustomQuest(
          title: '杂务', description: 'd', category: '杂务', tier: 1);
      final q = quests.state.availableQuests.last;
      quests.acceptQuest(q);
      quests.completeQuest(q);
      final countAfter1 = cult.state.profile.guMaterials
          .fold<int>(0, (sum, m) => sum + m.quantity);
      quests.completeQuest(q); // 已完成 → 直接返回
      final countAfter2 = cult.state.profile.guMaterials
          .fold<int>(0, (sum, m) => sum + m.quantity);
      expect(countAfter2, countAfter1);
    });
  });

  group('applyCultivationGains 共享奖励入口', () {
    test('道痕与流派感悟增加', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      cult.applyCultivationGains(
        daoKind: DaoKind.li,
        daoTraceAmount: 20,
        realmExpGain: 8,
      );
      final p = cult.state.profile;
      expect(p.daoTraces[DaoKind.li.index], 20);
      expect(p.factionRealmExp[Faction.li.daoKind.index], 8);
    });

    test('daoKind 为 null 时不增加道痕/感悟，但保留蛊材掉落入口', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      cult.applyCultivationGains(
        daoKind: null,
        daoTraceAmount: 10,
        realmExpGain: 10,
      );
      final p = cult.state.profile;
      expect(p.daoTraces, isEmpty);
      expect(p.factionRealmExp, isEmpty);
      // 无流派奖励（如杂务）仍可掉落蛊材
      expect(p.guMaterials, isNotEmpty);
    });

    test('applyMaterialDrop=false 时不触发蛊材掉落', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      cult.applyCultivationGains(
        daoKind: DaoKind.li,
        daoTraceAmount: 10,
        realmExpGain: 0,
        applyMaterialDrop: false,
      );
      expect(cult.state.profile.guMaterials, isEmpty);
    });

    test('蛊材掉落入口一致：相同 materialId 正确堆叠', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      for (var i = 0; i < 2; i++) {
        cult.applyCultivationGains(
          daoKind: DaoKind.li,
          daoTraceAmount: 5,
          realmExpGain: 2,
          random: _FixedRandom(0.0),
        );
      }
      final bronze = cult.state.profile.guMaterials
          .where((m) => m.materialId == 'bronze_sand')
          .toList();
      expect(bronze.length, 1);
      expect(bronze.first.quantity, 2);
    });

    test('不改变原任务奖励结果：任务路径与共享入口路径一致', () {
      final quest = QuestModel(
        id: 'q_1',
        title: '炼体',
        description: 'd',
        tier: 2,
        createdAt: DateTime(2026, 1, 1),
        category: '炼体',
      );

      // 任务路径
      final cult1 = CultivationNotifier(cultivationBox, statsBox);
      cult1.applyQuestCompletedRewards(quest, random: _FixedRandom(0.0));

      // 共享入口路径（等价参数）
      final cult2 = CultivationNotifier(cultivationBox, statsBox);
      final reward = computeCultivationReward(quest);
      cult2.applyCultivationGains(
        daoKind: reward.daoKind,
        daoTraceAmount: reward.daoTraceAmount,
        realmExpGain: reward.realmExpGain,
        random: _FixedRandom(0.0),
      );

      final p1 = cult1.state.profile;
      final p2 = cult2.state.profile;
      expect(p2.daoTraces[DaoKind.li.index], p1.daoTraces[DaoKind.li.index]);
      expect(
        p2.factionRealmExp[Faction.li.daoKind.index],
        p1.factionRealmExp[Faction.li.daoKind.index],
      );
      expect(
        p2.guMaterials.fold<int>(0, (sum, m) => sum + m.quantity),
        p1.guMaterials.fold<int>(0, (sum, m) => sum + m.quantity),
      );
    });
  });

  group('炼蛊 Provider', () {
    void giveMaterials(CultivationNotifier cult, Map<String, int> mats) {
      for (final e in mats.entries) {
        cult.state.profile.guMaterials
            .add(GuMaterial(materialId: e.key, quantity: e.value));
      }
    }

    test('成功扣材料并生成 GuInsect', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      cult.state.profile.factionRealmExp[DaoKind.lian.index] = 100000;
      giveMaterials(cult, {'bronze_sand': 5, 'iron_powder': 2});

      final result = cult.refineGuInsect(
        insectDefinitionId: 'bronze_beetle',
        random: _FixedRandom(0.0),
      );

      expect(result.success, isTrue);
      expect(cult.state.profile.guMaterials
              .firstWhere((m) => m.materialId == 'bronze_sand').quantity,
          2);
      expect(cult.state.profile.guMaterials
              .firstWhere((m) => m.materialId == 'iron_powder').quantity,
          1);
      expect(cult.state.profile.guInsects.length, 1);
      final insect = cult.state.profile.guInsects.first;
      expect(insect.definitionId, 'bronze_beetle');
      expect(insect.quality, inInclusiveRange(0, 1));
      expect(insect.refinedDaoLevel, FactionLevel.supremeGrandmaster.index);
    });

    test('失败扣材料但不生成蛊虫', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      cult.state.profile.factionRealmExp[DaoKind.lian.index] = 100000;
      giveMaterials(cult, {'bronze_sand': 5, 'iron_powder': 2});

      final result = cult.refineGuInsect(
        insectDefinitionId: 'bronze_beetle',
        random: _FixedRandom(1.0),
      );

      expect(result.success, isFalse);
      expect(cult.state.profile.guInsects, isEmpty);
      expect(cult.state.profile.guMaterials
              .firstWhere((m) => m.materialId == 'bronze_sand').quantity,
          2);
      expect(cult.state.profile.guMaterials
              .firstWhere((m) => m.materialId == 'iron_powder').quantity,
          1);
    });

    test('材料不足不修改库存、不生成蛊虫', () {
      final cult = CultivationNotifier(cultivationBox, statsBox);
      cult.state.profile.factionRealmExp[DaoKind.lian.index] = 100000;
      giveMaterials(cult, {'bronze_sand': 1});

      final result = cult.refineGuInsect(
        insectDefinitionId: 'bronze_beetle',
        random: _FixedRandom(0.0),
      );

      expect(result.success, isFalse);
      expect(result.failureReason, '蛊材不足');
      expect(cult.state.profile.guMaterials.single.quantity, 1);
      expect(cult.state.profile.guInsects, isEmpty);
    });

    test('炼道境界只来自 factionRealmExp，不由 daoTraces 推导', () {
      // 情形一：道痕 300000、感悟 0 → 炼道普通 → 九转蛊虫成功率 0.26，0.27 必败
      final cult1 = CultivationNotifier(cultivationBox, statsBox);
      cult1.state.profile.daoTraces[DaoKind.lian.index] = 300000;
      giveMaterials(cult1, {'blood_lotus': 20, 'nine_turn_spirit': 5});
      final r1 = cult1.refineGuInsect(
        insectDefinitionId: 'nine_turn_worm',
        random: _FixedRandom(0.27),
      );
      expect(r1.success, isFalse);

      // 情形二：道痕 0、感悟 100000 → 炼道无上大宗师 → 成功率 0.42，0.27 必成
      final cult2 = CultivationNotifier(cultivationBox, statsBox);
      cult2.state.profile.factionRealmExp[DaoKind.lian.index] = 100000;
      giveMaterials(cult2, {'blood_lotus': 20, 'nine_turn_spirit': 5});
      final r2 = cult2.refineGuInsect(
        insectDefinitionId: 'nine_turn_worm',
        random: _FixedRandom(0.27),
      );
      expect(r2.success, isTrue);
    });
  });
}

/// 固定值 Random，用于确定性控制成功/失败与掉落。
class _FixedRandom implements Random {
  final double doubleValue;

  _FixedRandom(this.doubleValue);

  @override
  double nextDouble() => doubleValue;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => doubleValue < 0.5;
}
