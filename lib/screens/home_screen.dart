import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../data/settings.dart';
import '../l10n/strings.dart';
import '../services/analyzer.dart';
import '../services/barcode_service.dart';
import '../services/cycle.dart';
import '../services/reminders.dart';
import '../widgets/common.dart';
import '../widgets/plate_hint_sheet.dart';
import '../widgets/profile_form.dart';
import 'cycle_screen.dart';
import 'manual_add_screen.dart';
import 'quick_text_screen.dart';
import 'result_screen.dart';
import 'saved_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const HomeScreen({super.key, required this.onChanged});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  double _today = 0;
  int _water = 0;
  List<DiaryEntry> _recent = [];
  List<DiaryEntry> _todayAll = [];
  // 1.1.1
  MealType? _copyMealType; // dünkü bu öğün bugüne kopyalanabilir
  int _copyKcal = 0;
  CycleInfo? _cycle;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final now = DateTime.now();
    final entries = await AppDb.instance.entriesForDay(now);
    final water = await AppDb.instance.water(now);
    // dünkü aynı öğün (bugün henüz girilmediyse) → tek dokunuşla kopyala
    final meal = Reminders.mealForNow();
    MealType? copy;
    var copyKcal = 0;
    if (!entries.any((e) => e.meal == meal)) {
      final y = (await AppDb.instance.entriesForDay(now.subtract(const Duration(days: 1))))
          .where((e) => e.meal == meal)
          .toList();
      if (y.isNotEmpty) {
        copy = meal;
        copyKcal = y.fold(0.0, (a, e) => a + e.kcal).round();
      }
    }
    CycleInfo? cyc;
    final st = Settings.instance;
    if (st.cycleOn && st.special == Special.none) {
      cyc = Cycle.compute(await AppDb.instance.periodStarts(), now,
          fallbackLength: st.cycleLen, periodLength: st.periodLen);
    }
    if (!mounted) return;
    setState(() {
      _today = entries.fold(0.0, (s, e) => s + e.kcal);
      _todayAll = entries;
      _recent = entries.reversed.take(3).toList();
      _water = water;
      _copyMealType = copy;
      _copyKcal = copyKcal;
      _cycle = cyc;
    });
    Reminders.pushToday(); // ana ekran widget'ı + akıllı hatırlatmalar
  }

  Future<void> _copyYesterday() async {
    final m = _copyMealType;
    if (m == null) return;
    final s = S.of(context);
    final n = await AppDb.instance.copyMeal(DateTime.now().subtract(const Duration(days: 1)), m);
    if (!mounted) return;
    showSnack(context, s.f('cp_done', {'n': n}));
    await refresh();
    widget.onChanged();
  }

  Future<void> _push(Widget page) async {
    final added = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => page));
    if (added == true) {
      await refresh();
      widget.onChanged();
    } else {
      refresh();
    }
  }

  Future<void> _profileSheet() async {
    final s = S.of(context);
    final key = GlobalKey<ProfileFormState>();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(s['pf_title'], style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(s['pf_text'], style: Theme.of(c).textTheme.bodySmall),
            const SizedBox(height: 14),
            ProfileForm(key: key),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                if (key.currentState?.save() ?? false) {
                  Navigator.pop(c, true);
                } else {
                  showSnack(c, s['pf_invalid']);
                }
              },
              child: Text(s['save']),
            ),
          ]),
        ),
      ),
    );
    if (ok == true) {
      Reminders.pushToday();
      setState(() {});
    }
  }

  Future<File?> _pick(ImageSource src) async {
    final x = await ImagePicker().pickImage(
        source: src, imageQuality: 92, maxWidth: 2000, maxHeight: 2000);
    return x == null ? null : File(x.path);
  }

  Future<void> _analyze(ImageSource src) async {
    final file = await _pick(src);
    if (file == null || !mounted) return;
    final input = await showPlateHintSheet(context, file);
    if (input == null || !mounted) return; // cancelled
    final s = S.of(context);
    final lang = Settings.instance.lang;
    final stage = ValueNotifier<AnalysisStage>(AnalysisStage.online);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProgressDialog(stage: stage, file: file),
    );
    AnalysisResult? result;
    try {
      result = await Analyzer.analyze(file, lang,
          input: input, onStage: (st) => stage.value = st);
    } catch (_) {}
    if (!mounted) return;
    Navigator.pop(context); // progress
    if (result == null) {
      showSnack(context, s['error_analysis']);
      return;
    }
    if (result.note == 'no_internet') {
      showSnack(context, s['no_internet_offline']);
    } else if (result.errorKey != null) {
      showSnack(context,
          '${s[result.errorKey!]} ${s['offline_used']}\n(${result.errorDetail ?? ''})');
    }
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ResultScreen(result: result!)),
    );
    if (added == true) {
      await refresh();
      widget.onChanged();
    }
  }

  Future<void> _barcode() async {
    final file = await _pick(ImageSource.camera);
    if (file == null || !mounted) return;
    final s = S.of(context);
    final code = await BarcodeService.readBarcode(file);
    if (!mounted) return;
    if (code == null) {
      showSnack(context, s['barcode_not_found']);
      return;
    }
    final r = await BarcodeService.lookup(code, Settings.instance.lang);
    if (!mounted) return;
    if (r == null) {
      showSnack(context, s['barcode_not_found']);
      return;
    }
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ResultScreen(result: r)),
    );
    if (added == true) {
      await refresh();
      widget.onChanged();
    }
  }

  Future<void> _manual() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ManualAddScreen()),
    );
    if (added == true) {
      await refresh();
      widget.onChanged();
    }
  }

  Future<void> _addWater(int delta) async {
    final v = (_water + delta).clamp(0, 30);
    await AppDb.instance.setWater(DateTime.now(), v);
    setState(() => _water = v);
    Reminders.pushToday();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final goal = Settings.instance.dailyGoal.toDouble();
    final remaining = goal - _today;
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          GradientCard(
            child: Row(
              children: [
                CalorieRing(
                  consumed: _today,
                  goal: goal,
                  size: 140,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${_today.round()}',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800)),
                      Text(s['kcal'],
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['today'],
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 6),
                      Text(
                        remaining >= 0
                            ? '${s['remaining']}: ${remaining.round()}'
                            : '${s['over_goal']}: ${(-remaining).round()}',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                      ),
                      Text('${s['daily_goal']}: ${goal.round()} ${s['kcal']}',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.water_drop_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text('$_water/${Settings.instance.waterGoal} ${s['glasses']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ),
                          _waterBtn(Icons.remove, () => _addWater(-1), s['wt_less']),
                          SizedBox(width: 6),
                          _waterBtn(Icons.add, () => _addWater(1), s['wt_more']),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          _macroBars(s),
          if (!Settings.instance.profileSet) ...[
            SizedBox(height: 12),
            _promptCard(
              icon: Icons.tune_rounded,
              color: AppColors.rose,
              title: s['pf_title'],
              text: s['pf_prompt'],
              onTap: _profileSheet,
            ),
          ],
          if (_copyMealType != null) ...[
            SizedBox(height: 12),
            _promptCard(
              icon: Icons.content_copy_rounded,
              color: AppColors.lavender,
              title: s.f('cp_yesterday', {'m': s[_copyMealType!.name]}),
              text: '$_copyKcal ${s['kcal']} · ${s['cp_one_tap']}',
              onTap: _copyYesterday,
            ),
          ],
          if (_cycle != null) ...[
            SizedBox(height: 12),
            _promptCard(
              icon: Icons.favorite_rounded,
              color: AppColors.rose,
              title: '${s['cy_phase_${_cycle!.phase}']} · ${s.f('cy_day_of', {'d': _cycle!.day, 'n': _cycle!.length})}',
              text: s['cy_tip_${_cycle!.phase}'],
              onTap: () => _push(const CycleScreen()),
            ),
          ],
          SizedBox(height: 22),
          Text(s['analyze_photo'],
              style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              ActionTile(
                  icon: Icons.photo_camera_rounded,
                  label: s['take_photo'],
                  color: AppColors.rose,
                  onTap: () => _analyze(ImageSource.camera)),
              ActionTile(
                  icon: Icons.photo_library_rounded,
                  label: s['from_gallery'],
                  color: AppColors.lavender,
                  onTap: () => _analyze(ImageSource.gallery)),
              ActionTile(
                  icon: Icons.qr_code_scanner_rounded,
                  label: s['scan_barcode'],
                  color: AppColors.mint,
                  onTap: _barcode),
              ActionTile(
                  icon: Icons.edit_note_rounded,
                  label: s['manual_add'],
                  color: AppColors.peach,
                  onTap: _manual),
              ActionTile(
                  icon: Icons.mic_rounded,
                  label: s['qt_tile'],
                  color: AppColors.rose,
                  onTap: () => _push(const QuickTextScreen())),
              ActionTile(
                  icon: Icons.star_rounded,
                  label: s['sv_tile'],
                  color: AppColors.lavender,
                  onTap: () => _push(const SavedScreen())),
            ],
          ),
          SizedBox(height: 22),
          if (_recent.isNotEmpty) ...[
            Text(s['today'], style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 12),
            ..._recent.map((e) => Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        _thumb(e.imagePath),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(s[e.meal.name],
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Text('${e.kcal.round()} ${s['kcal']}',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.rose)),
                      ],
                    ),
                  ),
                )),
          ],
          SizedBox(height: 10),
          SoftCard(
            color: AppColors.lavenderSoft.withValues(alpha: 0.4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_rounded, color: AppColors.lavender),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['tips_title'],
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text(s['tips_text'],
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 1.1.1: bugünün makroları hedefe göre (ince çubuklar).
  Widget _macroBars(S s) {
    final st = Settings.instance;
    double sum(double Function(DiaryEntry) f) => _todayAll.fold(0.0, (a, e) => a + f(e));
    Widget bar(String label, double v, double t, Color c) => Expanded(
          child: Semantics(
            label: '$label ${v.round()} / ${t.round()} g',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: t > 0 ? (v / t).clamp(0.0, 1.0) : 0),
                  duration: const Duration(milliseconds: 600),
                  builder: (_, f, __) => LinearProgressIndicator(
                      value: f, minHeight: 7, color: c, backgroundColor: c.withValues(alpha: 0.15)),
                ),
              ),
              const SizedBox(height: 3),
              Text('${v.round()} / ${t.round()} g',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        bar(s['protein'], sum((e) => e.protein), st.proteinTarget, AppColors.protein),
        const SizedBox(width: 14),
        bar(s['carbs'], sum((e) => e.carbs), st.carbsTarget, AppColors.carbs),
        const SizedBox(width: 14),
        bar(s['fat'], sum((e) => e.fat), st.fatTarget, AppColors.fat),
      ]),
    );
  }

  Widget _promptCard({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: SoftCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
          ]),
        ),
      );

  Widget _waterBtn(IconData i, VoidCallback onTap, String tip) => Tooltip(
      message: tip,
      child: Semantics(button: true, label: tip, child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(i, color: Colors.white, size: 18),
        ),
      )));

  static Widget _thumb(String? path) {
    final f = path == null ? null : File(path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 52,
        height: 52,
        child: f != null && f.existsSync()
            ? Image.file(f, fit: BoxFit.cover)
            : Container(
                color: AppColors.roseSoft.withValues(alpha: 0.3),
                child: Icon(Icons.restaurant_rounded,
                    color: AppColors.rose)),
      ),
    );
  }
}

class _ProgressDialog extends StatelessWidget {
  final ValueNotifier<AnalysisStage> stage;
  final File file;
  const _ProgressDialog({required this.stage, required this.file});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(file, height: 180, fit: BoxFit.cover),
            ),
            SizedBox(height: 18),
            CircularProgressIndicator(color: AppColors.rose),
            SizedBox(height: 14),
            ValueListenableBuilder<AnalysisStage>(
              valueListenable: stage,
              builder: (_, st, __) => Text(
                st == AnalysisStage.online
                    ? s['analyzing_online']
                    : s['analyzing_offline'],
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
