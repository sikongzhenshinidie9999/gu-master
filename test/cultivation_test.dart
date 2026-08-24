import 'dart:io';

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
    profile.guInsects.add(GuInsect(id: 'g1', turn: 2, refinedDaoLevel: 3));
    profile.guMaterials.add(GuMaterial(type: 0, quantity: 5));
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
}
