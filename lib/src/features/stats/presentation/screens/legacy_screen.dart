import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sidequest/src/features/cultivation/data/dao.dart';
import 'package:sidequest/src/features/cultivation/data/player_profile.dart';
import 'package:sidequest/src/features/cultivation/logic/cultivation_provider.dart';
import 'package:sidequest/src/features/cultivation/logic/faction_realm.dart';
import 'package:sidequest/src/features/quests/logic/quest_provider.dart';
import 'package:sidequest/src/features/stats/logic/realm.dart';
import 'package:sidequest/src/shared/widgets/glass_card.dart';
import 'package:intl/intl.dart';

class LegacyScreen extends ConsumerWidget {
  const LegacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questState = ref.watch(questProvider);
    final cultivationState = ref.watch(cultivationProvider);

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
                  realm.name,
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
            realm.isMaxRealm
                ? "已达最高境界"
                : "距离 ${realm.nextName} 还需 $needNext 修为",
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
