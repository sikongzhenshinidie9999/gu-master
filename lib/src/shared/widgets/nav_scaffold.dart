import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidequest/src/features/cultivation/logic/cultivation_provider.dart';
import 'package:sidequest/src/features/cultivation/logic/tribulation_service.dart' as tribulation;
import 'package:sidequest/src/shared/widgets/app_snackbar.dart';
import '../../features/quests/presentation/screens/the_board_screen.dart';
import '../../features/quests/presentation/screens/active_quests_screen.dart';
import '../../features/stats/presentation/screens/legacy_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import 'global_header.dart';
import 'background_gradient.dart';

class NavScaffold extends ConsumerStatefulWidget {
  const NavScaffold({super.key});

  @override
  ConsumerState<NavScaffold> createState() => _NavScaffoldState();
}

class _NavScaffoldState extends ConsumerState<NavScaffold> {
  int _currentIndex = 0;

  // 自动弹窗：记录上一个「已到期劫难」键（当前转-stage），到期变化时弹出
  String? _prevDueKey;

  final List<Widget> _screens = [
    const TheBoardScreen(),
    const ActiveQuestsScreen(),
    const LegacyScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInitialDue());
  }

  void _checkInitialDue() {
    if (!mounted) return;
    final notifier = ref.read(cultivationProvider.notifier);
    final due = notifier.dueTribulationStageForCurrentRealm;
    if (due == null) return;
    final realm = notifier.currentRealmLevel;
    _prevDueKey = '$realm-$due';
    _showTribulationDialog(due, realm);
  }

  void _checkDueChange(CultivationState state) {
    final notifier = ref.read(cultivationProvider.notifier);
    final due = notifier.dueTribulationStageForCurrentRealm;
    final realm = notifier.currentRealmLevel;
    final key = due == null ? null : '$realm-$due';
    if (key != null && key != _prevDueKey) {
      final dueStage = due!;
      final dueRealm = realm;
      _prevDueKey = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showTribulationDialog(dueStage, dueRealm);
      });
    } else if (key == null) {
      _prevDueKey = null;
    }
  }

  void _showTribulationDialog(int stage, int realmLevel) {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // 只能点击渡劫
      builder: (dialogContext) => AlertDialog(
        title: const Text('劫难已至'),
        content: Text(
          realmLevel == 9
              ? '修为已达，九转尊者劫降临，必须渡过。'
              : '修为已达该转数 ${stage + 1}/3，劫难降临，必须渡过。',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              final notifier = ref.read(cultivationProvider.notifier);
              final result = notifier.attemptTribulation(
                realmLevel: realmLevel,
                stageIndex: stage,
              );
              Navigator.pop(dialogContext);
              _showTribulationFeedback(result);
            },
            child: const Text('渡劫'),
          ),
        ],
      ),
    );
  }

  void _showTribulationFeedback(tribulation.TribulationResult result) {
    final String msg;
    switch (result.outcome) {
      case tribulation.TribulationOutcome.success:
        msg = '渡劫成功';
        break;
      case tribulation.TribulationOutcome.failure:
        msg = '渡劫失败 · 修为 -${result.cultivationPenalty}';
        break;
      case tribulation.TribulationOutcome.onCooldown:
        msg = '渡劫冷却中';
        break;
      case tribulation.TribulationOutcome.invalid:
        msg = '当前无法渡劫';
        break;
    }
    showAppSnackBar(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    // 监听修为/渡劫状态变化，劫难到期自动弹出
    ref.listen<CultivationState>(
      cultivationProvider,
      (prev, next) => _checkDueChange(next),
    );
    return Scaffold(
      body: BackgroundGradient(
        child: SafeArea(
          child: Column(
            children: [
              GlobalHeader(
                onSettingsTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
              ),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.square_list),
            activeIcon: Icon(CupertinoIcons.square_list_fill),
            label: '修炼任务',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.compass),
            activeIcon: Icon(CupertinoIcons.compass_fill),
            label: '修炼中',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.graph_circle),
            activeIcon: Icon(CupertinoIcons.graph_circle_fill),
            label: '修炼成果',
          ),
        ],
      ),
    );
  }
}
