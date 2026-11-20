import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme.dart';
import 'data/settings.dart';
import 'l10n/strings.dart';
import 'screens/diary_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'services/food_db.dart';
import 'widgets/window_controls.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.instance.init();
  await FoodDb.instance.load();
  await initializeDateFormatting();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const KaloriApp());
}

class KaloriApp extends StatelessWidget {
  const KaloriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.instance,
      builder: (context, _) => MaterialApp(
        title: 'Kalori Hesaplayıcı',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: Locale(Settings.instance.lang),
        supportedLocales: S.supported,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Settings.instance.welcomed ? const Shell() : const Welcome(),
      ),
    );
  }
}

class Welcome extends StatelessWidget {
  const Welcome({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = Settings.instance;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.restaurant_rounded,
                      size: 56, color: Colors.white),
                ),
                const SizedBox(height: 28),
                Text(s['welcome_title'],
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(s['welcome_text'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
                const Spacer(),
                Row(
                  children: [
                    for (final l in const [
                      ('tr', 'turkish'),
                      ('en', 'english'),
                      ('ar', 'arabic')
                    ])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: ChoiceChip(
                            label: Center(child: Text(s[l.$2])),
                            selected: st.lang == l.$1,
                            selectedColor: Colors.white,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.25),
                            labelStyle: TextStyle(
                                color: st.lang == l.$1
                                    ? AppColors.rose
                                    : Colors.white),
                            onSelected: (_) => st.lang = l.$1,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.rose),
                  onPressed: () {
                    st.welcomed = true;
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const Shell()));
                  },
                  child: Text(s['ok']),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  final _homeKey = GlobalKey<HomeScreenState>();
  final _diaryKey = GlobalKey<DiaryScreenState>();
  final _statsKey = GlobalKey<StatsScreenState>();

  void _refreshAll() {
    _homeKey.currentState?.refresh();
    _diaryKey.currentState?.refresh();
    _statsKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final titles = [s['app_name'], s['diary'], s['stats'], s['settings']];
    final pages = [
      HomeScreen(key: _homeKey, onChanged: _refreshAll),
      DiaryScreen(key: _diaryKey, onChanged: _refreshAll),
      StatsScreen(key: _statsKey),
      const SettingsScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: const [WindowControls()],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 1) _diaryKey.currentState?.refresh();
          if (i == 2) _statsKey.currentState?.refresh();
        },
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded, color: AppColors.rose),
              label: s['home']),
          NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon:
                  const Icon(Icons.menu_book_rounded, color: AppColors.rose),
              label: s['diary']),
          NavigationDestination(
              icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon:
                  const Icon(Icons.bar_chart_rounded, color: AppColors.rose),
              label: s['stats']),
          NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon:
                  const Icon(Icons.settings_rounded, color: AppColors.rose),
              label: s['settings']),
        ],
      ),
    );
  }
}
