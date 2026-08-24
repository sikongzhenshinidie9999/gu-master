import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'src/features/cultivation/data/dao_zhu.dart';
import 'src/features/cultivation/data/gu_insect.dart';
import 'src/features/cultivation/data/gu_material.dart';
import 'src/features/cultivation/data/player_profile.dart';
import 'src/features/cultivation/data/tribulation_record.dart';
import 'src/features/cultivation/logic/cultivation_provider.dart';
import 'src/features/quests/data/quest_model.dart';
import 'src/features/quests/logic/quest_provider.dart';
import 'src/features/settings/logic/settings_provider.dart';
import 'src/shared/widgets/nav_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Hive Setup
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) {
     Hive.registerAdapter(QuestModelAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(PlayerProfileAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(TribulationRecordAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(GuInsectAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(GuMaterialAdapter());
  }
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(DaoZhuStateAdapter());
  }
  
  // Open Boxes
  final questBox = await Hive.openBox<QuestModel>('quests');
  await Hive.openBox('stats');
  await Hive.openBox('settings');
  final cultivationBox = await Hive.openBox<PlayerProfile>('cultivation');

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  runApp(
    ProviderScope(
      overrides: [
        questBoxProvider.overrideWithValue(questBox),
        cultivationBoxProvider.overrideWithValue(cultivationBox),
      ],
      child: const SidequestApp(),
    ),
  );
}

class SidequestApp extends ConsumerWidget {
  const SidequestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: '蛊师修炼系统',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const NavScaffold(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    
    return base.copyWith(
      scaffoldBackgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7),
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: brightness,
      ),
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        selectedItemColor: Colors.deepPurpleAccent,
        unselectedItemColor: Colors.grey,
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}
