import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../data/db.dart';
import '../data/settings.dart';
import '../l10n/strings.dart';
import '../services/cycle.dart';
import '../widgets/common.dart';

/// 1.1.1 — Adet döngüsü takibi: evreye göre iştah, su ve beslenme notları.
/// Veriler yalnız bu cihazda (ve kullanıcının kendi eşitlemesinde) durur.
class CycleScreen extends StatefulWidget {
  const CycleScreen({super.key});

  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends State<CycleScreen> {
  List<DateTime> _starts = [];
  bool _loaded = false;
  final st = Settings.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await AppDb.instance.periodStarts();
    if (!mounted) return;
    setState(() {
      _starts = s;
      _loaded = true;
    });
  }

  Future<void> _mark(DateTime d) async {
    await AppDb.instance.setPeriodStart(d, true);
    if (!st.cycleOn) st.cycleOn = true;
    _load();
  }

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (d != null) _mark(d);
  }

  Future<void> _remove(DateTime d) async {
    await AppDb.instance.setPeriodStart(d, false);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = Settings.instance.lang;
    final info = Cycle.compute(_starts, DateTime.now(),
        fallbackLength: st.cycleLen, periodLength: st.periodLen);
    final df = DateFormat.yMMMMd(lang);
    return Scaffold(
      appBar: AppBar(title: Text(s['cy_title'])),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                if (info == null)
                  EmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: s['cy_empty'],
                    text: s['cy_empty_hint'],
                    action: s['cy_started_today'],
                    onAction: () => _mark(DateTime.now()),
                  )
                else ...[
                  GradientCard(
                    child: Row(children: [
                      _DayDial(day: info.day, length: info.length),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s['cy_phase_${info.phase}'],
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(s.f('cy_day_of', {'d': info.day, 'n': info.length}),
                              style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text(
                              info.late
                                  ? s['cy_late']
                                  : s.f('cy_next', {'n': info.daysToNext, 'd': df.format(info.nextStart)}),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  _tip(Icons.restaurant_rounded, s['cy_appetite'], s['cy_tip_${info.phase}'], AppColors.rose),
                  _tip(Icons.water_drop_rounded, s['cy_water'], s['cy_water_${info.phase}'], AppColors.lavender),
                  _tip(Icons.eco_rounded, s['cy_food'], s['cy_food_${info.phase}'], AppColors.mint),
                ],
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _mark(DateTime.now()),
                      icon: const Icon(Icons.water_drop_outlined),
                      label: Text(s['cy_started_today']),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _pick,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(s['cy_other_day']),
                  ),
                ]),
                const SizedBox(height: 18),
                Text(s['cy_settings'], style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SoftCard(
                  child: Column(children: [
                    _stepper(s['cy_len'], st.cycleLen, 21, 45, (v) => st.cycleLen = v),
                    _stepper(s['cy_period_len'], st.periodLen, 2, 10, (v) => st.periodLen = v),
                    Text(s['cy_len_hint'], style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
                if (_starts.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(s['cy_history'], style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final d in _starts.reversed.take(12))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: SoftCard(
                        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 4),
                        child: Row(children: [
                          Icon(Icons.circle, size: 10, color: AppColors.rose),
                          const SizedBox(width: 10),
                          Expanded(child: Text(df.format(d))),
                          IconButton(
                            tooltip: s['sv_remove'],
                            onPressed: () => _remove(d),
                            icon: Icon(Icons.close_rounded, color: AppColors.inkSoft),
                          ),
                        ]),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                Text(s['cy_disclaimer'],
                    textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
    );
  }

  Widget _tip(IconData icon, String title, String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SoftCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(text, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ]),
        ),
      );

  Widget _stepper(String label, int v, int min, int max, void Function(int) set) => Row(children: [
        Expanded(child: Text(label)),
        IconButton(
            tooltip: '−',
            onPressed: v <= min ? null : () => setState(() => set(v - 1)),
            icon: const Icon(Icons.remove_circle_outline_rounded)),
        SizedBox(
            width: 34,
            child: Text('$v', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
        IconButton(
            tooltip: '+',
            onPressed: v >= max ? null : () => setState(() => set(v + 1)),
            icon: const Icon(Icons.add_circle_outline_rounded)),
      ]);
}

class _DayDial extends StatelessWidget {
  final int day, length;
  const _DayDial({required this.day, required this.length});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 92,
        height: 92,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 92,
            height: 92,
            child: CircularProgressIndicator(
              value: (day / length).clamp(0.0, 1.0),
              strokeWidth: 8,
              color: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          Text('$day', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
        ]),
      );
}
