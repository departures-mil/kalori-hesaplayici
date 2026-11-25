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
import 'services/reminders.dart';
import 'services/update_service.dart';
import 'widgets/announcements.dart';
import 'widgets/common.dart';
import 'widgets/look_picker.dart';
import 'widgets/profile_form.dart';
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
  unawaited(FcLook.instance.loadDynamic()); // Android 12+ Material You renkleri ("Sistem" şeması)
  unawaited(Reminders.apply()); // hatırlatmalar (güncelleme / yeniden başlatma sonrası da)
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

/// İlk açılış rehberi: 1) tanıtım + dil  2) kişisel hedef  3) görünüm  4) kendi yapay zekâ anahtarı.
class Welcome extends StatefulWidget {
  const Welcome({super.key});

  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  int _step = 0;
  final _key = TextEditingController();
  final _profile = GlobalKey<ProfileFormState>();

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 1 && !(_profile.currentState?.save() ?? true)) {
      showSnack(context, S.of(context)['pf_invalid']);
      return;
    }
    setState(() => _step++);
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
        const SizedBox(height: 20),
        // kısa tanıtım: uygulamanın yaptıkları
        Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
          for (final f in const [
            (Icons.photo_camera_rounded, 'onb_f_photo'),
            (Icons.mic_rounded, 'onb_f_voice'),
            (Icons.qr_code_scanner_rounded, 'onb_f_barcode'),
            (Icons.insights_rounded, 'onb_f_report'),
          ])
            Container(
              width: 140,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                  color: white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Icon(f.$1, color: white, size: 26),
                const SizedBox(height: 6),
                Text(s[f.$2],
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: white, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
        const SizedBox(height: 24),
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
      // 2) kişisel hedef (Mifflin-St Jeor)
      Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.flag_rounded, size: 54, color: white),
        const SizedBox(height: 16),
        title(s['pf_title']),
        const SizedBox(height: 10),
        body(s['pf_text']),
        const SizedBox(height: 16),
        ProfileForm(key: _profile, onGradient: true),
      ]),
      // 3) görünüm
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
      // 4) kendi yapay zekâ anahtarı
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
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (c, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                          position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a),
                          child: c),
                    ),
                    child: KeyedSubtree(key: ValueKey(_step), child: pages[_step]),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(children: [
                for (var i = 0; i < pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
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
                  onPressed: last ? _finish : _next,
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

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _index = 0;
  final _homeKey = GlobalKey<HomeScreenState>();
  final _diaryKey = GlobalKey<DiaryScreenState>();
  final _statsKey = GlobalKey<StatsScreenState>();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 1.1.1: uygulamaya dönünce (gün değişmiş olabilir) ekranlar ve widget yenilenir.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAll();
    if (state == AppLifecycleState.paused) unawaited(Reminders.pushToday());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
