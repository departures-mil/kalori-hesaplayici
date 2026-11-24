import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/app_info.dart';
import 'core/look.dart';
import 'core/theme.dart';
import 'data/settings.dart';
import 'l10n/strings.dart';
import 'screens/diary_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'services/fc_agent.dart';
import 'services/fc_contact.dart';
import 'services/fc_crash.dart';
import 'services/food_db.dart';
import 'services/food_model.dart';
import 'services/nutrition_db.dart';
import 'services/portion_learner.dart';
import 'services/update_service.dart';
import 'widgets/announcements.dart';
import 'widgets/look_picker.dart';
import 'widgets/window_controls.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FcCrash.install(); // FlutterError.onError + PlatformDispatcher.onError → admin gelen kutusu
  await Settings.instance.init();
  await FcLook.instance.init();
  FcContact.lang = () => Settings.instance.lang;
  await FoodDb.instance.load();
  await PortionLearner.instance.init();
  NutritionDb.instance.load(); // USDA table, in the background
  FoodModel.instance.autoDownload(); // offline food model, Wi‑Fi only
  await initializeDateFormatting();
  await FcAgent.instance.init(
    app: kAppId,
    version: kAppVersion,
    lang: () => Settings.instance.lang,
    ai: () {
      final k = Settings.instance.geminiKey; // yalnız kullanıcının KENDİ anahtarı
      return k.isEmpty ? null : {'provider': 'gemini', 'key': k};
    },
  );
  unawaited(FcContact.flush()); // gönderilemeyen mesajlar / çökme raporları
  unawaited(UpdateService.cleanup());
  // Renk şeması değişince bütün ekranlar yeni renklerle yeniden çizilir (durum korunur).
  FcLook.instance.addListener(_repaintAll);
  runApp(const KaloriApp());
}

void _repaintAll() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(mark);
  });
}

class KaloriApp extends StatelessWidget {
  const KaloriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Settings.instance, FcLook.instance]),
      builder: (context, _) {
        final look = FcLook.instance;
        final lang = Settings.instance.lang;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: look.dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: look.dark ? Brightness.dark : Brightness.light,
        ));
        return MaterialApp(
          title: kAppName,
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: FcAgent.messengerKey,
          theme: buildTheme(lang: lang),
          locale: Locale(lang),
          supportedLocales: S.supported,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                  textScaler: TextScaler.linear(mq.textScaler.scale(1) * look.scale)),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: Settings.instance.welcomed ? const Shell() : const Welcome(),
        );
      },
    );
  }
}

/// İlk açılış rehberi: 1) dil  2) görünüm  3) kendi yapay zekâ anahtarı.
class Welcome extends StatefulWidget {
  const Welcome({super.key});

  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  int _step = 0;
  final _key = TextEditingController();

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  void _finish() {
    final st = Settings.instance;
    final k = _key.text.trim();
    if (k.isNotEmpty) st.setKeys(gemini: k);
    st.lastSeenVersion = kAppVersion; // ilk kurulumda "neler yeni" gösterilmez
    st.welcomed = true;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Shell()));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = Settings.instance;
    const white = Colors.white;
    Widget title(String t) => Text(t,
        textAlign: TextAlign.center,
        style: const TextStyle(color: white, fontSize: 24, fontWeight: FontWeight.w700));
    Widget body(String t) => Text(t,
        textAlign: TextAlign.center, style: const TextStyle(color: white, fontSize: 15, height: 1.4));

    final pages = <Widget>[
      // 1) dil
      Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(color: white.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: const Icon(Icons.restaurant_rounded, size: 54, color: white),
        ),
        const SizedBox(height: 24),
        Text(s['welcome_title'],
            style: const TextStyle(color: white, fontSize: 30, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        body(s['welcome_text']),
        const SizedBox(height: 28),
        Text(s['onb_lang'], style: const TextStyle(color: white, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          for (final l in const [('tr', 'turkish'), ('en', 'english'), ('ar', 'arabic')])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: ChoiceChip(
                  label: Center(child: Text(s[l.$2])),
                  selected: st.lang == l.$1,
                  showCheckmark: false,
                  selectedColor: white,
                  backgroundColor: white.withValues(alpha: 0.25),
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                      color: st.lang == l.$1 ? FcLook.instance.palette.gradient.first : white,
                      fontWeight: FontWeight.w600),
                  onSelected: (_) => st.lang = l.$1,
                ),
              ),
            ),
        ]),
      ]),
      // 2) görünüm
      Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.palette_rounded, size: 54, color: white),
        const SizedBox(height: 16),
        title(s['onb_look']),
        const SizedBox(height: 10),
        body(s['onb_look_text']),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.card, borderRadius: BorderRadius.circular(20)),
          child: const LookPicker(compact: true),
        ),
      ]),
      // 3) kendi yapay zekâ anahtarı
      Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.key_rounded, size: 54, color: white),
        const SizedBox(height: 16),
        title(s['onb_ai']),
        const SizedBox(height: 10),
        body(s['onb_ai_text']),
        const SizedBox(height: 16),
        TextField(
          controller: _key,
          obscureText: true,
          onChanged: (_) => setState(() {}),
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(labelText: s['gemini_key']),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: white),
          onPressed: () => launchUrl(Uri.parse('https://aistudio.google.com/apikey'),
              mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(s['onb_ai_get']),
        ),
        Text(s['onb_ai_later'],
            textAlign: TextAlign.center,
            style: TextStyle(color: white.withValues(alpha: 0.85), fontSize: 12)),
      ]),
    ];

    final last = _step == pages.length - 1;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: kGradient),
        child: SafeArea(
          child: Column(children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
                  child: pages[_step],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(children: [
                for (var i = 0; i < pages.length; i++)
                  Container(
                    width: i == _step ? 22 : 8,
                    height: 8,
                    margin: const EdgeInsetsDirectional.only(end: 6),
                    decoration: BoxDecoration(
                        color: white.withValues(alpha: i == _step ? 1 : 0.45),
                        borderRadius: BorderRadius.circular(4)),
                  ),
                const Spacer(),
                if (_step > 0)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: white),
                    onPressed: () => setState(() => _step--),
                    child: Text(s['onb_back']),
                  ),
                if (last && _key.text.trim().isEmpty)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: white),
                    onPressed: _finish,
                    child: Text(s['onb_skip']),
                  ),
                const SizedBox(width: 6),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: white,
                      foregroundColor: FcLook.instance.palette.gradient.first,
                      minimumSize: const Size(110, 48)),
                  onPressed: last ? _finish : () => setState(() => _step++),
                  child: Text(last ? s['onb_done'] : s['onb_next']),
                ),
              ]),
            ),
          ]),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showWhatsNew(context); // güncellemeden sonraki ilk açılışta
      if (!mounted) return;
      await startupUpdateCheck(context); // açılışta bir kez; yeni sürüm varsa pencere
    });
  }

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
      SettingsScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 14,
        title: Text(titles[_index], overflow: TextOverflow.ellipsis),
        actions: [FcAgentButton(), AnnouncementBell(), WindowControls()],
      ),
      body: Listener(
        onPointerDown: (_) => FcAgent.instance.input(),
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          FcAgent.instance.track(titles[i]);
          if (i == 1) _diaryKey.currentState?.refresh();
          if (i == 2) _statsKey.currentState?.refresh();
        },
        destinations: [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.rose),
              label: s['home']),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded, color: AppColors.rose),
              label: s['diary']),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded, color: AppColors.rose),
              label: s['stats']),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded, color: AppColors.rose),
              label: s['settings']),
        ],
      ),
    );
  }
}
