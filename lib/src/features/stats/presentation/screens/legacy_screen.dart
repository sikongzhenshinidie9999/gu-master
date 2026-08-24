import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sidequest/src/features/cultivation/data/dao.dart';
import 'package:sidequest/src/features/cultivation/data/faction_level.dart';
import 'package:sidequest/src/features/cultivation/data/gu_insect_definition.dart';
import 'package:sidequest/src/features/cultivation/data/gu_material_definition.dart';
import 'package:sidequest/src/features/cultivation/data/gu_recipe.dart';
import 'package:sidequest/src/features/cultivation/data/player_profile.dart';
import 'package:sidequest/src/features/cultivation/data/tribulation_record.dart';
import 'package:sidequest/src/features/cultivation/logic/cultivation_provider.dart';
import 'package:sidequest/src/features/cultivation/logic/faction_realm.dart';
import 'package:sidequest/src/features/cultivation/logic/nine_turn_prerequisites.dart';
import 'package:sidequest/src/features/cultivation/logic/refining_service.dart';
import 'package:sidequest/src/features/cultivation/logic/tribulation_config.dart';
import 'package:sidequest/src/features/cultivation/logic/tribulation_service.dart';
import 'package:sidequest/src/features/quests/logic/quest_provider.dart';
import 'package:sidequest/src/features/stats/logic/realm.dart';
import 'package:sidequest/src/shared/widgets/app_snackbar.dart';
import 'package:sidequest/src/shared/widgets/glass_card.dart';
import 'package:intl/intl.dart';

class LegacyScreen extends ConsumerWidget {
  const LegacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questState = ref.watch(questProvider);
    // 状态监听：ref.watch(cultivationProvider)（正确监听 Provider state 变化）
    final cultivationState = ref.watch(cultivationProvider);
    // 只读 getter / action：ref.read(cultivationProvider.notifier)
    final cultivationNotifier = ref.read(cultivationProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroStats(context, questState.totalXp, cultivationState.profile),
          const SizedBox(height: 20),
          _buildDaoTraces(context, cultivationState.profile),
          const SizedBox(height: 20),
          _buildFactionRealms(context, cultivationState.profile),
          const SizedBox(height: 20),
          _buildNineTurnCard(context, cultivationState.profile, cultivationNotifier),
          const SizedBox(height: 20),
          _buildDaoZhuCard(context, cultivationState.profile, cultivationNotifier),
          const SizedBox(height: 20),
          _buildTribulationCard(
              context, cultivationState.profile, cultivationNotifier),
          const SizedBox(height: 20),
          _buildMaterialInventory(context, ref, cultivationState.profile),
          const SizedBox(height: 20),
          _buildGuInsects(context, cultivationState.profile),
          const SizedBox(height: 20),
          _buildWeeklyProgress(context, questState.weeklyHistory),
          const SizedBox(height: 24),
          Text(
            "修炼记录",
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildHistoryList(context, questState.completedQuests),
        ],
      ),
    );
  }

  Widget _buildHeroStats(
      BuildContext context, int totalXp, PlayerProfile profile) {
    final realm = getRealmProgress(totalXp);
    final needNext = realm.isMaxRealm ? 0 : (realm.nextThreshold! - totalXp);

    // 名义转数（realm.dart）与真实九转突破（nineTurnReached）严格区分：
    // - 名义已达九转但未真正突破 → 显示「八转巅峰 · 待突破」；
    // - 已真正突破 → 显示「九转蛊尊」+ 突破时间。
    final String heroRealmName;
    final String heroRealmSubtitle;
    if (profile.nineTurnReached) {
      heroRealmName = '九转蛊尊';
      final at = profile.nineTurnBreakthroughAt;
      heroRealmSubtitle = at == null
          ? '已突破九转'
          : '九转突破于 ${DateFormat('yyyy-MM-dd HH:mm').format(at)}';
    } else if (realm.level == 9) {
      heroRealmName = '八转巅峰 · 待突破';
      heroRealmSubtitle = '已达名义九转门槛，尚未完成真正突破';
    } else {
      heroRealmName = realm.name;
      heroRealmSubtitle = realm.isMaxRealm
          ? '已达最高境界'
          : '距离 ${realm.nextName} 还需 $needNext 修为';
    }

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            "总修为",
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            NumberFormat.decimalPattern().format(totalXp),
            style: GoogleFonts.outfit(
              fontSize: 56, 
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                const SizedBox(width: 6),
                Text(
                  heroRealmName,
                  style: const TextStyle(
                    fontSize: 11, 
                    color: Colors.amber, 
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: realm.progress,
              minHeight: 8,
              backgroundColor: Colors.amber.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            heroRealmSubtitle,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '累计修为：${NumberFormat.decimalPattern().format(profile.totalXp)}　当前修为：${NumberFormat.decimalPattern().format(profile.currentCultivation)}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaoTraces(BuildContext context, PlayerProfile profile) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                '道痕',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final kind in DaoKind.values)
            if (kind != DaoKind.none)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(kind.label, style: const TextStyle(fontSize: 14)),
                    Text(
                      '${profile.daoTraces[kind.index] ?? 0}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildFactionRealms(BuildContext context, PlayerProfile profile) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.military_tech_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                '流派境界',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final faction in Faction.values)
            _buildFactionRealmRow(context, profile, faction),
        ],
      ),
    );
  }

  Widget _buildFactionRealmRow(
      BuildContext context, PlayerProfile profile, Faction faction) {
    final realmExp = profile.factionRealmExp[faction.daoKind.index] ?? 0;
    final realm = getFactionRealmProgress(faction, realmExp);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                faction.label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Text(
                realm.level.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: realm.progress,
              minHeight: 6,
              backgroundColor:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            realm.isCapped
                ? '境界已达无上大宗师，感悟仍可继续积累（感悟 ${NumberFormat.decimalPattern().format(realmExp)}）'
                : '感悟 ${NumberFormat.decimalPattern().format(realmExp)} / ${NumberFormat.decimalPattern().format(realm.nextThreshold!)}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNineTurnCard(BuildContext context, PlayerProfile profile,
      CultivationNotifier cultivationNotifier) {
    // 只消费 Provider 只读 getter（6A/6B），不在 UI 重算任何业务条件。
    final prereq = cultivationNotifier.nineTurnPrerequisites;
    final primary = prereq.primaryFaction;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.military_tech_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                '九转',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _prereqRow('主修流派', primary?.label ?? '未指定'),
          _prereqRow(
            '道痕',
            '${prereq.currentDaoTraces} / ${prereq.daoTraceRequirement ?? 0}${prereq.daoTracesSatisfied ? ' ✓' : ' ✗'}',
          ),
          _prereqRow(
            '流派境界',
            '${prereq.factionRealmLevel?.label ?? '未知'}${prereq.factionRealmSatisfied ? ' ✓' : ' ✗'}',
          ),
          _prereqRow('白荔仙元', prereq.xianYuanSatisfied ? '已具备' : '未具备'),
          _prereqRow('尊者劫', prereq.tribulationSatisfied ? '已完成' : '未完成'),
          _prereqRow('总体', prereq.canBreakthrough ? '条件已满足，可突破' : '条件未满足'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              // 仅「已突破」禁用；条件不足时点击由 Provider 返回失败原因
              onPressed: profile.nineTurnReached
                  ? null
                  : () {
                      final result = cultivationNotifier
                          .attemptNineTurnBreakthrough(
                        tribulationSatisfied:
                            cultivationNotifier.nineTurnTribulationSatisfied,
                      );
                      _showNineTurnResult(context, result);
                    },
              child: const Text('尝试突破'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTribulationCard(BuildContext context, PlayerProfile profile,
      CultivationNotifier cultivationNotifier) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                '渡劫',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final realmLevel in const [6, 7, 8, 9])
            _buildTribulationRow(
                context, profile, realmLevel, cultivationNotifier),
        ],
      ),
    );
  }

  Widget _buildTribulationRow(BuildContext context, PlayerProfile profile,
      int realmLevel, CultivationNotifier cultivationNotifier) {
    // 当前状态 = 该转数 stageIndex 最高的记录（无记录 = 未开始/未完成）
    TribulationRecord? record;
    for (final r in profile.tribulations) {
      if (r.realmLevel == realmLevel &&
          (record == null || r.stageIndex > record.stageIndex)) {
        record = r;
      }
    }
    final stageIndex = record?.stageIndex;
    final isVenerable = realmLevel == 9;
    final isCompleted =
        stageIndex != null && stageIndex >= kTribulationCompletedStageIndex;
    final failCount = record?.failCount ?? 0;
    final onCooldown = isTribulationOnCooldown(
      lastAttemptAt: record?.lastAttemptAt,
      now: DateTime.now(),
    );
    final rate = calculateTribulationSuccessRate(
      realmLevel: realmLevel,
      failCount: failCount,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVenerable ? '九转尊者劫' : '${_realmNumberLabel(realmLevel)}转',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Text(
                _tribulationStageLabel(isVenerable, stageIndex),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isCompleted
                      ? Colors.green
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '成功率：${(rate * 100).round()}%${failCount > 0 ? ' · 失败 $failCount 次' : ''}${onCooldown ? ' · 冷却中' : ''}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCompleted
                  ? null
                  : () {
                      final result = cultivationNotifier.attemptTribulation(
                        realmLevel: realmLevel,
                        stageIndex: stageIndex ?? 0,
                      );
                      _showTribulationResult(context, result);
                    },
              child: const Text('渡劫'),
            ),
          ),
        ],
      ),
    );
  }

  void _showTribulationResult(
      BuildContext context, TribulationResult result) {
    switch (result.outcome) {
      case TribulationOutcome.success:
        showAppSnackBar(
          context,
          '渡劫成功 · 成功率 ${(result.successRate * 100).round()}% · 进入 ${_tribulationStageLabel(result.realmLevel == 9, result.nextStageIndex)}',
        );
        break;
      case TribulationOutcome.failure:
        showAppSnackBar(
          context,
          '渡劫失败 · 成功率 ${(result.successRate * 100).round()}% · 修为 -${result.cultivationPenalty}',
        );
        break;
      case TribulationOutcome.onCooldown:
        showAppSnackBar(context, '渡劫冷却中');
        break;
      case TribulationOutcome.invalid:
        showAppSnackBar(context, '当前无法渡劫');
        break;
    }
  }

  void _showNineTurnResult(
      BuildContext context, NineTurnBreakthroughResult result) {
    switch (result.status) {
      case NineTurnBreakthroughStatus.succeeded:
        showAppSnackBar(context, '九转突破成功 · 白荔仙元已质变为黄杏仙元');
        break;
      case NineTurnBreakthroughStatus.alreadyReached:
        showAppSnackBar(context, '已突破九转');
        break;
      case NineTurnBreakthroughStatus.failed:
        showAppSnackBar(
            context, '九转突破失败：${result.failureReason ?? '前置条件未满足'}');
        break;
    }
  }

  Widget _buildDaoZhuCard(BuildContext context, PlayerProfile profile,
      CultivationNotifier cultivationNotifier) {
    final daoZhu = profile.daoZhu;
    if (daoZhu != null) {
      // 已授予：道主身份（唯一来源 profile.daoZhu；九转蛊尊与道主是独立概念）
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.workspace_premium_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  '道主',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _prereqRow('道主流派', _factionLabel(daoZhu.faction)),
            _prereqRow(
                '授予时间', DateFormat('yyyy-MM-dd HH:mm').format(daoZhu.crownedAt)),
            if (daoZhu.eraId.isNotEmpty) _prereqRow('时代', daoZhu.eraId),
            _prereqRow('状态', '已授予'),
          ],
        ),
      );
    }

    // 未授予：道主资格（只消费 Provider 只读 getter，不复制资格公式）
    final primary = resolvePrimaryFaction(profile);
    final eligibility = cultivationNotifier.daoZhuEligibility;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                '道主',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _prereqRow('授予流派', primary?.label ?? '尚未确定主修流派'),
          _prereqRow('九转', eligibility.nineTurnSatisfied ? '✓' : '✗'),
          _prereqRow('流派境界', eligibility.factionRealmSatisfied ? '✓' : '✗'),
          _prereqRow('道痕', eligibility.daoTracesSatisfied ? '✓' : '✗'),
          _prereqRow('当世理解最深',
              eligibility.deepestUnderstandingSatisfied ? '✓' : '✗'),
          _prereqRow('总体资格', eligibility.canGrant ? '✓' : '✗'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              // 无主修流派禁止授予；deepest 恒 false（无真实来源，不虚构业务事实）
              onPressed: primary == null
                  ? null
                  : () {
                      final result = cultivationNotifier.grantDaoZhu(
                        faction: primary,
                        isDeepestUnderstanding: false,
                      );
                      _showDaoZhuResult(context, result);
                    },
              child: const Text('尝试授予道主'),
            ),
          ),
        ],
      ),
    );
  }

  void _showDaoZhuResult(BuildContext context, DaoZhuGrantResult result) {
    switch (result.status) {
      case DaoZhuGrantStatus.succeeded:
        final label = result.daoZhu == null
            ? ''
            : _factionLabel(result.daoZhu!.faction);
        showAppSnackBar(context, '道主授予成功 · $label');
        break;
      case DaoZhuGrantStatus.alreadyGranted:
        showAppSnackBar(context, '已经是道主');
        break;
      case DaoZhuGrantStatus.failed:
        showAppSnackBar(
            context, '道主授予失败：${result.failureReason ?? '资格未满足'}');
        break;
    }
  }

  Widget _buildMaterialInventory(
      BuildContext context, WidgetRef ref, PlayerProfile profile) {
    final owned = profile.guMaterials.where((m) => m.quantity > 0).toList();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.inventory_2_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '蛊材',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showRefineDialog(context, ref, profile),
                icon: const Icon(Icons.science_rounded, size: 18),
                label: const Text('炼蛊'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (owned.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '暂无蛊材',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            )
          else
            for (final m in owned)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_materialLabel(m.materialId)}（${_materialRarityLabel(m.materialId)}）',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      '×${NumberFormat.decimalPattern().format(m.quantity)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildGuInsects(BuildContext context, PlayerProfile profile) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pest_control_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                '本命蛊 / 蛊虫',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (profile.guInsects.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '暂无蛊虫',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            )
          else
            for (final insect in profile.guInsects)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _insectName(insect.definitionId),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      '${_qualityLabel(insect.quality)} · ${_factionLabel(insect.faction)} · ${insect.turn} 转 · 炼道 ${_factionLevelLabel(insect.refinedDaoLevel)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _showRefineDialog(
      BuildContext context, WidgetRef ref, PlayerProfile profile) async {
    final notifier = ref.read(cultivationProvider.notifier);
    // 炼道境界只来自 factionRealmExp（感悟），绝不由 daoTraces（道痕）推导
    final lianRealmExp = profile.factionRealmExp[DaoKind.lian.index] ?? 0;
    final lianDaoLevel =
        getFactionRealmProgress(Faction.lian, lianRealmExp).level;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('炼蛊'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '炼道境界：${lianDaoLevel.label}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                for (final recipe in kGuRecipes)
                  _buildRecipeTile(
                      dialogContext, notifier, profile, recipe, lianDaoLevel),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeTile(
      BuildContext context, CultivationNotifier notifier, PlayerProfile profile,
      GuRecipe recipe, FactionLevel lianDaoLevel) {
    final definition = _findInsectDefinition(recipe.insectDefinitionId);
    final name = definition?.name ?? '未知蛊虫';
    final turn = definition?.turn ?? 0;
    final factionLabel = definition?.faction.label ?? '未知流派';
    final rate = definition == null
        ? 0.0
        : refiningSuccessRate(
            insectTurn: definition.turn, lianDaoLevel: lianDaoLevel);

    final missing = <String>[];
    for (final need in recipe.materials) {
      final have = _materialCount(profile, need.materialId);
      if (have < need.quantity) missing.add(_materialLabel(need.materialId));
    }
    final canRefine = definition != null && missing.isEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('$turn 转 · $factionLabel',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 6),
            for (final need in recipe.materials)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  '${_materialLabel(need.materialId)} ×${need.quantity}（拥有 ${_materialCount(profile, need.materialId)}）',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 4),
            Text('预计成功率：${(rate * 100).round()}%',
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.primary)),
            if (!canRefine)
              Text('缺少：${missing.join('、')}',
                  style: const TextStyle(fontSize: 12, color: Colors.red)),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canRefine
                    ? () {
                        final result = notifier.refineGuInsect(
                          insectDefinitionId: recipe.insectDefinitionId,
                        );
                        Navigator.pop(context);
                        _showRefineResult(context, result);
                      }
                    : null,
                child: const Text('炼制'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRefineResult(BuildContext context, RefiningResult result) {
    final gained = result.gainedInsect;
    if (result.success && gained != null) {
      showAppSnackBar(context,
          '炼蛊成功 · 获得 ${gained.name}（${_qualityLabel(gained.quality)}）· ${gained.turn} 转');
    } else {
      showAppSnackBar(context, '炼蛊失败 · 材料已消耗');
    }
  }
  Widget _buildWeeklyProgress(BuildContext context, Map<DateTime, String> history) {
    final now = DateTime.now();
    // Start from Monday of the current week
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.date_range_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                "本周修炼",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final date = startOfWeek.add(Duration(days: index));
              final dayName = DateFormat('E').format(date)[0];
              final isToday = date.day == now.day && date.month == now.month;
              
              // Normalize to midnight for key lookup
              final key = DateTime(date.year, date.month, date.day);
              final status = history[key];
              
              return Column(
                children: [
                  Text(
                    dayName, 
                    style: TextStyle(
                      color: isToday 
                          ? Theme.of(context).colorScheme.primary 
                          : Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildDayIndicator(status, isToday),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDayIndicator(String? status, bool isToday) {
    IconData icon;
    Color color;

    switch (status) {
      case 'completed':
        icon = Icons.check_circle_rounded;
        color = Colors.green;
        break;
      case 'failed':
        icon = Icons.cancel_rounded;
        color = Colors.red;
        break;
      case 'frozen':
        icon = Icons.ac_unit_rounded;
        color = Colors.blue;
        break;
      default:
        icon = Icons.circle_outlined;
        color = Colors.grey.withValues(alpha: 0.3);
    }

    if (isToday && status == null) {
      return Container(
        height: 28,
        width: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blueAccent, width: 2),
        ),
      );
    }

    return Icon(icon, color: color, size: 28);
  }

  Widget _buildHistoryList(BuildContext context, List quests) {
    if (quests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.history_edu_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              const Text(
                "你的修炼之路，从今日开始。",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    
    // Show only last 5 quests
    final displayQuests = quests.reversed.take(5).toList();
    
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayQuests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final quest = displayQuests[index];
        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: quest.categoryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  quest.icon, 
                  size: 20, 
                  color: quest.categoryColor
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    Text(
                      DateFormat('MMM d, h:mm a').format(quest.acceptedAt ?? DateTime.now()),
                      style: TextStyle(fontSize: 11, color: Colors.grey.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "+${quest.xpReward} 修为",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.green,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _materialLabel(String materialId) {
  for (final d in kGuMaterialDefinitions) {
    if (d.materialId == materialId) return d.label;
  }
  return '未知蛊材';
}

String _materialRarityLabel(String materialId) {
  for (final d in kGuMaterialDefinitions) {
    if (d.materialId == materialId) return d.rarity.label;
  }
  return '未知品质';
}

String _insectName(String definitionId) {
  for (final d in kGuInsectDefinitions) {
    if (d.definitionId == definitionId) return d.name;
  }
  return '未知蛊虫';
}

String _factionLabel(int index) {
  if (index >= 0 && index < Faction.values.length) {
    return Faction.values[index].label;
  }
  return '未知流派';
}

String _qualityLabel(int quality) {
  switch (quality) {
    case 0:
      return '普通';
    case 1:
      return '稀有';
    case 2:
      return '特殊';
    default:
      return '品质$quality';
  }
}

String _factionLevelLabel(int index) {
  if (index >= 0 && index < FactionLevel.values.length) {
    return FactionLevel.values[index].label;
  }
  return '未知';
}

int _materialCount(PlayerProfile profile, String materialId) {
  for (final m in profile.guMaterials) {
    if (m.materialId == materialId) return m.quantity;
  }
  return 0;
}

GuInsectDefinition? _findInsectDefinition(String definitionId) {
  for (final d in kGuInsectDefinitions) {
    if (d.definitionId == definitionId) return d;
  }
  return null;
}

/// 九转卡行（纯展示，不参与业务计算）。
Widget _prereqRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Text(
      '$label：$value',
      style: const TextStyle(fontSize: 13),
    ),
  );
}

/// 渡劫小阶标签：0→1/3、1→2/3、2→3/3、3→已完成；尊者劫 0→未完成。
String _tribulationStageLabel(bool isVenerable, int? stageIndex) {
  if (stageIndex == null) return isVenerable ? '未完成' : '未开始';
  if (stageIndex >= kTribulationCompletedStageIndex) return '已完成';
  if (isVenerable) return '未完成';
  return '${stageIndex + 1}/3';
}

/// 转数中文标签（仅 6/7/8 需要）。
String _realmNumberLabel(int realmLevel) {
  switch (realmLevel) {
    case 6:
      return '六';
    case 7:
      return '七';
    case 8:
      return '八';
    default:
      return '$realmLevel';
  }
}
