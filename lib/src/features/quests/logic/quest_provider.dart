import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../data/quest_model.dart';
import '../../stats/logic/realm.dart';

// --- Hive Box Provider ---
final questBoxProvider = Provider<Box<QuestModel>>((ref) {
  throw UnimplementedError('questBoxProvider not initialized');
});

// --- State Definitions ---
class QuestState {
  final List<QuestModel> availableQuests;
  final List<QuestModel> activeQuests;
  final List<QuestModel> completedQuests;
  final int streak;
  final int totalXp;
  final DateTime? lastCompletedDate;
  final Map<DateTime, String> weeklyHistory;
  final bool canShuffle;
  // 最近一次境界突破事件（仅内存态，绝不进入 Hive）。
  final RealmBreakthrough? lastBreakthrough;

  QuestState({
    required this.availableQuests,
    required this.activeQuests,
    required this.completedQuests,
    this.streak = 0,
    this.totalXp = 0,
    this.lastCompletedDate,
    this.weeklyHistory = const {},
    this.canShuffle = true,
    this.lastBreakthrough,
  });

  QuestState copyWith({
    List<QuestModel>? availableQuests,
    List<QuestModel>? activeQuests,
    List<QuestModel>? completedQuests,
    int? streak,
    int? totalXp,
    DateTime? lastCompletedDate,
    Map<DateTime, String>? weeklyHistory,
    bool? canShuffle,
    RealmBreakthrough? lastBreakthrough,
    bool clearLastBreakthrough = false,
  }) {
    return QuestState(
      availableQuests: availableQuests ?? this.availableQuests,
      activeQuests: activeQuests ?? this.activeQuests,
      completedQuests: completedQuests ?? this.completedQuests,
      streak: streak ?? this.streak,
      totalXp: totalXp ?? this.totalXp,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      weeklyHistory: weeklyHistory ?? this.weeklyHistory,
      canShuffle: canShuffle ?? this.canShuffle,
      lastBreakthrough: clearLastBreakthrough
          ? null
          : (lastBreakthrough ?? this.lastBreakthrough),
    );
  }
}

// --- Notifier ---
class QuestNotifier extends StateNotifier<QuestState> {
  final Box<QuestModel> box;
  final Box<dynamic> statsBox;
  final Box<dynamic> settingsBox;

  QuestNotifier(this.box, this.statsBox, this.settingsBox)
      : super(QuestState(
          availableQuests: [],
          activeQuests: [],
          completedQuests: [],
          streak: statsBox.get('streak', defaultValue: 0),
          totalXp: statsBox.get('totalXp', defaultValue: 0),
          lastCompletedDate: statsBox.get('lastCompletedDate'),
          weeklyHistory: (statsBox.get('weeklyHistory') as Map?)?.cast<DateTime, String>() ?? {},
          canShuffle: true, // Init value, updated in load
        )) {
    _loadInitialData();
  }

  void _loadInitialData() {
    final allQuests = box.values.toList();
    
    // Purge bad data
    final badQuests = allQuests.where((q) => 
        (q.category == 'General' || q.category == '') && 
        q.acceptedAt == null 
    ).toList();
    for (var q in badQuests) {
      q.delete();
    }

    final cleanQuests = box.values.toList();
    final available = cleanQuests.where((q) => q.acceptedAt == null && !q.isCompleted && !q.isFailed).toList();
    final active = cleanQuests.where((q) => q.isActive).toList();
    final completed = cleanQuests.where((q) => q.isCompleted).toList();

    final lastRefresh = statsBox.get('lastRefresh', defaultValue: DateTime(2000));
    final lastShuffle = statsBox.get('lastShuffle', defaultValue: DateTime(2000));
    final now = DateTime.now();

    if (!_isSameDay(lastRefresh, now) || available.isEmpty) {
      _refreshDailyQuests(available);
      statsBox.put('lastRefresh', now);
      // Reset shuffle availability on new day
      state = state.copyWith(canShuffle: true);
    } else {
      state = state.copyWith(
        availableQuests: available,
        activeQuests: active,
        completedQuests: completed,
        canShuffle: !_isSameDay(lastShuffle, now),
      );
    }
    
    _checkExpiredQuests();
  }

  void _refreshDailyQuests(List<QuestModel> currentAvailable) {
    for (var q in currentAvailable) {
      q.delete();
    }

    final newQuests = [
      _generateQuest(tier: 1),
      _generateQuest(tier: 1),
      _generateQuest(tier: 2),
      _generateQuest(tier: 2),
      _generateQuest(tier: 3),
      _generateQuest(tier: 3),
    ];
    
    box.addAll(newQuests);
    state = state.copyWith(availableQuests: newQuests);
  }

  void shuffleQuests() {
    if (!state.canShuffle) return;

    final now = DateTime.now();
    statsBox.put('lastShuffle', now);
    
    _refreshDailyQuests(state.availableQuests);
    
    state = state.copyWith(canShuffle: false);
  }

  QuestModel _generateQuest({required int tier}) {
    final List<Map<String, String>> pool;

    if (tier == 1) {
      pool = [
        {'title': '打坐静心 15 分钟', 'desc': '静下心来，感受体内气息流转。', 'cat': '炼神'},
        {'title': '早起修炼', 'desc': '清晨起床后先运转一小段功法。', 'cat': '炼气'},
        {'title': '活动筋骨 10 分钟', 'desc': '简单拉伸活动，唤醒身体。', 'cat': '炼体'},
        {'title': '阅读一章书', 'desc': '读一章功法典籍或闲书。', 'cat': '悟道'},
        {'title': '清理修炼洞府', 'desc': '把修炼环境收拾干净。', 'cat': '杂务'},
        {'title': '学习一项新知识', 'desc': '学一个以前不懂的小知识。', 'cat': '悟道'},
        {'title': '睡前静心', 'desc': '睡前静坐五分钟，平复心神。', 'cat': '炼神'},
        {'title': '完成今日最重要的一项事情', 'desc': '今天最要紧的一件事，先做完它。', 'cat': '杂务'},
        {'title': '给蛊虫喂食', 'desc': '照料一下你养的蛊虫。', 'cat': '炼蛊'},
        {'title': '散步吐纳', 'desc': '散步时配合呼吸吐纳。', 'cat': '炼气'},
      ];
    } else if (tier == 2) {
      pool = [
        {'title': '研读功法 20 分钟', 'desc': '认真研读功法典籍二十分钟。', 'cat': '悟道'},
        {'title': '运转功法三周天', 'desc': '完整运转功法三个周天。', 'cat': '炼气'},
        {'title': '锻炼体魄 30 分钟', 'desc': '进行三十分钟的体能修炼。', 'cat': '炼体'},
        {'title': '打坐入定 30 分钟', 'desc': '进入较深的静定状态。', 'cat': '炼神'},
        {'title': '整理今日修炼心得', 'desc': '把今日修炼感悟写成笔记。', 'cat': '悟道'},
        {'title': '喂养蛊虫并观察状态', 'desc': '记录蛊虫今日的变化。', 'cat': '炼蛊'},
        {'title': '彻底清扫洞府', 'desc': '对修炼洞府做一次大扫除。', 'cat': '杂务'},
        {'title': '复盘今日修炼成果', 'desc': '回顾今天的修炼进度与得失。', 'cat': '悟道'},
        {'title': '观想气息归入丹田', 'desc': '冥想观想，气息归元。', 'cat': '炼神'},
        {'title': '熬炼药浴强身', 'desc': '准备并泡一次药浴，强健体魄。', 'cat': '炼体'},
      ];
    } else { // Tier 3
      pool = [
        {'title': '闭关修炼一小时', 'desc': '排除干扰，持续修炼一个小时。', 'cat': '炼气'},
        {'title': '高强度炼体 60 分钟', 'desc': '完成一次高强度的体能修炼。', 'cat': '炼体'},
        {'title': '深度观想 45 分钟', 'desc': '长时间保持深度冥想状态。', 'cat': '炼神'},
        {'title': '炼制一份蛊毒', 'desc': '按配方炼制一份蛊毒或蛊引。', 'cat': '炼蛊'},
        {'title': '参悟上乘功法', 'desc': '静心参悟一篇上乘功法。', 'cat': '悟道'},
        {'title': '深度复盘与规划', 'desc': '系统复盘本周修炼并制定计划。', 'cat': '悟道'},
        {'title': '洞府全面修整', 'desc': '全面修缮、布置你的修炼洞府。', 'cat': '杂务'},
        {'title': '炼化蛊虫精元', 'desc': '尝试炼化一只蛊虫的精元。', 'cat': '炼蛊'},
        {'title': '断网一日清修', 'desc': '一整天不使用电子产品，清修养神。', 'cat': '炼神'},
        {'title': '长途跋涉采药', 'desc': '外出采药，锻炼体魄与意志。', 'cat': '炼体'},
      ];
    }

    final random = Random();
    final data = pool[random.nextInt(pool.length)];
    
    return QuestModel(
      id: const Uuid().v4(),
      title: data['title']!,
      description: data['desc']!,
      tier: tier,
      createdAt: DateTime.now(),
      category: data['cat']!,
    );
  }

  void acceptQuest(QuestModel quest) {
    quest.acceptedAt = DateTime.now();
    quest.save();

    state = state.copyWith(
      availableQuests: state.availableQuests.where((q) => q.id != quest.id).toList(),
      activeQuests: [...state.activeQuests, quest],
    );
  }

  void completeQuest(QuestModel quest) {
    // 先清空上一次突破事件，避免本次未突破时遗留旧事件
    state = state.copyWith(clearLastBreakthrough: true);

    quest.isCompleted = true;
    quest.save();

    final oldTotalXp = state.totalXp;
    final newXp = oldTotalXp + quest.xpReward;
    statsBox.put('totalXp', newXp);

    _updateStreak();
    _updateWeeklyHistory(DateTime.now(), 'completed');

    final breakthrough = detectRealmBreakthrough(
      oldTotalXp: oldTotalXp,
      newTotalXp: newXp,
      gainedXp: quest.xpReward,
    );

    state = state.copyWith(
      activeQuests: state.activeQuests.where((q) => q.id != quest.id).toList(),
      completedQuests: [...state.completedQuests, quest],
      totalXp: newXp,
      lastBreakthrough: breakthrough,
    );
  }
  
  /// 晋升反馈展示完成后清除突破事件（仅内存态）。
  void clearLastBreakthrough() {
    if (state.lastBreakthrough != null) {
      state = state.copyWith(clearLastBreakthrough: true);
    }
  }

  void failQuest(QuestModel quest) {
    quest.isFailed = true;
    quest.save();
    
    _updateWeeklyHistory(DateTime.now(), 'failed');
    
    state = state.copyWith(
       activeQuests: state.activeQuests.where((q) => q.id != quest.id).toList(),
    );
  }

  void _updateStreak() {
    final now = DateTime.now();
    final lastDate = state.lastCompletedDate;
    final isVacation = settingsBox.get('vacationMode', defaultValue: false);
    
    int newStreak = state.streak;

    if (lastDate == null) {
      newStreak = 1;
    } else if (_isSameDay(lastDate, now)) {
      // Already completed a quest today
    } else if (_isYesterday(lastDate, now)) {
      newStreak += 1;
    } else {
      // Missed a day
      if (!isVacation) {
        newStreak = 1; // Reset streak if not on vacation
      }
      // If on vacation, we preserve the streak (do nothing to it)
    }
    
    statsBox.put('streak', newStreak);
    statsBox.put('lastCompletedDate', now);
    
    state = state.copyWith(
      streak: newStreak,
      lastCompletedDate: now,
    );
  }

  void _updateWeeklyHistory(DateTime date, String status) {
    final key = DateTime(date.year, date.month, date.day);
    final newHistory = Map<DateTime, String>.from(state.weeklyHistory);
    
    if (!newHistory.containsKey(key) || newHistory[key] == 'frozen') {
       newHistory[key] = status;
       statsBox.put('weeklyHistory', newHistory);
       state = state.copyWith(weeklyHistory: newHistory);
    }
  }

  void _checkExpiredQuests() {
    final now = DateTime.now();
    for (var quest in state.activeQuests) {
      if (quest.expiryTime != null && now.isAfter(quest.expiryTime!)) {
        failQuest(quest);
      }
    }
  }
  
  // Danger Zone
  Future<void> wipeAllData() async {
    await box.clear();
    await statsBox.clear();
    // Re-init with defaults
    state = QuestState(
      availableQuests: [],
      activeQuests: [],
      completedQuests: [],
      streak: 0,
      totalXp: 0,
    );
    _loadInitialData(); // Reload to generate fresh quests
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }
  
  bool _isYesterday(DateTime d1, DateTime d2) {
    final yesterday = d2.subtract(const Duration(days: 1));
    return _isSameDay(d1, yesterday);
  }
}

// --- Provider Definition ---
final questProvider = StateNotifierProvider<QuestNotifier, QuestState>((ref) {
  final box = ref.watch(questBoxProvider);
  final statsBox = Hive.box('stats');
  final settingsBox = Hive.box('settings');
  return QuestNotifier(box, statsBox, settingsBox);
});
