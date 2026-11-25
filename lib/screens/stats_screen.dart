import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../data/settings.dart';
import '../l10n/strings.dart';
import '../widgets/common.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => StatsScreenState();
}

class StatsScreenState extends State<StatsScreen> {
  int _days = 7;
  List<DaySummary> _data = [];
  List<MapEntry<DateTime, double>> _weights = [];
  Map<String, num> _life = {};
  // 1.1.1: makrolar, su ve dönem raporu
  List<DiaryEntry> _entries = [];
  Map<String, int> _waterMap = {};
  double _prevAvg = 0;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final d = await AppDb.instance.dailyTotals(days: _days);
    final w = await AppDb.instance.weights();
    final l = await AppDb.instance.lifetimeStats();
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day - (_days - 1));
    final e = await AppDb.instance.entriesBetween(from, now);
    final wm = await AppDb.instance.waterBetween(from, now);
    // önceki dönemin ortalaması (karşılaştırma)
    final pe = await AppDb.instance.entriesBetween(
        DateTime(from.year, from.month, from.day - _days),
        DateTime(from.year, from.month, from.day - 1));
    final pDays = <String, double>{};
    for (final x in pe) {
      final k = AppDb.dayKey(x.time);
      pDays[k] = (pDays[k] ?? 0) + x.kcal;
    }
    if (!mounted) return;
    setState(() {
      _data = d;
      _weights = w;
      _life = l;
      _entries = e;
      _waterMap = wm;
      _prevAvg = pDays.isEmpty ? 0 : pDays.values.reduce((a, b) => a + b) / pDays.length;
    });
  }

  Future<void> _addWeight() async {
    final s = S.of(context);
    final c = TextEditingController(
        text: Settings.instance.weight.toStringAsFixed(1));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s['add_weight']),
        content: TextField(
            controller: c,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: s['weight_kg'])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s['cancel'])),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s['save'])),
        ],
      ),
    );
    if (ok != true) return;
    final kg = double.tryParse(c.text.replaceAll(',', '.'));
    if (kg == null || kg <= 0) return;
    await AppDb.instance.setWeight(DateTime.now(), kg);
    Settings.instance.setProfile(weight: kg);
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final goal = Settings.instance.dailyGoal.toDouble();
    final lang = Settings.instance.lang;

    // Fill in missing days with zero.
    final now = DateTime.now();
    final series = <DaySummary>[];
    for (var i = _days - 1; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final key = AppDb.dayKey(day);
      final found = _data.where((d) => AppDb.dayKey(d.day) == key);
      series.add(found.isEmpty ? DaySummary(day, 0, 0) : found.first);
    }
    final tracked = series.where((d) => d.entries > 0).toList();
    final avg = tracked.isEmpty
        ? 0.0
        : tracked.fold(0.0, (a, d) => a + d.kcal) / tracked.length;
    final maxY = [goal, ...series.map((d) => d.kcal)]
            .reduce((a, b) => a > b ? a : b) *
        1.15;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            ChoiceChip(
              label: Text(s['week']),
              selected: _days == 7,
              selectedColor: AppColors.roseSoft,
              onSelected: (_) {
                setState(() => _days = 7);
                refresh();
              },
            ),
            SizedBox(width: 8),
            ChoiceChip(
              label: Text(s['month']),
              selected: _days == 30,
              selectedColor: AppColors.roseSoft,
              onSelected: (_) {
                setState(() => _days = 30);
                refresh();
              },
            ),
            Spacer(),
            Text('${s['average']}: ${avg.round()} ${s['kcal']}',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        SizedBox(height: 14),
        SoftCard(
          padding: EdgeInsets.fromLTRB(8, 20, 16, 8),
          child: SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                      '${rod.toY.round()} ${s['kcal']}',
                      TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                        color: AppColors.lavenderSoft.withValues(alpha: 0.6),
                        strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                      y: goal,
                      color: AppColors.lavender,
                      strokeWidth: 1.5,
                      dashArray: [6, 4]),
                ]),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(),
                  rightTitles: AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text('${v.round()}',
                            style: TextStyle(
                                fontSize: 10, color: AppColors.inkSoft))),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= series.length) {
                          return SizedBox();
                        }
                        if (_days == 30 && i % 5 != 0) return SizedBox();
                        final d = series[i].day;
                        return Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            _days == 7
                                ? DateFormat.E(lang).format(d)
                                : DateFormat.d(lang).format(d),
                            style: TextStyle(
                                fontSize: 10, color: AppColors.inkSoft),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < series.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: series[i].kcal,
                        width: _days == 7 ? 18 : 6,
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          colors: series[i].kcal > goal
                              ? [AppColors.peach, AppColors.rose]
                              : [AppColors.lavender, AppColors.rose],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ]),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _stat(s['history_total'], '${_life['n'] ?? 0}',
                    Icons.list_alt_rounded, AppColors.lavender)),
            SizedBox(width: 10),
            Expanded(
                child: _stat(s['days_tracked'], '${_life['days'] ?? 0}',
                    Icons.calendar_month_rounded, AppColors.rose)),
          ],
        ),
        SizedBox(height: 22),
        _reportCard(s, series, goal, avg),
        SizedBox(height: 22),
        Text(s['st_macros'], style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: 4),
        Text(s['st_macros_hint'], style: Theme.of(context).textTheme.bodySmall),
        SizedBox(height: 10),
        _macroCard(s, tracked.length),
        SizedBox(height: 22),
        Text(s['st_water'], style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: 10),
        _waterCard(s, series, lang),
        SizedBox(height: 22),
        Row(
          children: [
            Text(s['weight_log'],
                style: Theme.of(context).textTheme.titleLarge),
            Spacer(),
            TextButton.icon(
                onPressed: _addWeight,
                icon: Icon(Icons.add),
                label: Text(s['add_weight'])),
          ],
        ),
        SizedBox(height: 8),
        SoftCard(
          padding: EdgeInsets.fromLTRB(8, 20, 16, 8),
          child: SizedBox(
            height: 180,
            child: _weights.length < 2
                ? Center(
                    child: Text(s['no_entries'],
                        style: Theme.of(context).textTheme.bodySmall))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(drawVerticalLine: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: AxisTitles(),
                        rightTitles: AxisTitles(),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (v, _) => Text(
                                  v.toStringAsFixed(0),
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.inkSoft))),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: (_weights.length / 4).ceilToDouble(),
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 || i >= _weights.length) {
                                return SizedBox();
                              }
                              return Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                    DateFormat.Md(lang)
                                        .format(_weights[i].key),
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.inkSoft)),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < _weights.length; i++)
                              FlSpot(i.toDouble(), _weights[i].value)
                          ],
                          isCurved: true,
                          color: AppColors.rose,
                          barWidth: 3,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.rose.withValues(alpha: 0.12)),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// Dönem raporu: hedefte kalınan gün, en yüksek / düşük gün, kilo değişimi, önceki döneme göre.
  Widget _reportCard(S s, List<DaySummary> series, double goal, double avg) {
    final tracked = series.where((d) => d.entries > 0).toList();
    if (tracked.isEmpty) {
      return SoftCard(
          child: EmptyState(
              icon: Icons.insights_rounded, title: s['st_report'], text: s['st_report_empty']));
    }
    final onTarget = tracked.where((d) => (d.kcal - goal).abs() <= goal * 0.1).length;
    final hi = tracked.reduce((a, b) => a.kcal >= b.kcal ? a : b);
    final lo = tracked.reduce((a, b) => a.kcal <= b.kcal ? a : b);
    final lang = Settings.instance.lang;
    final df = DateFormat.MMMd(lang);
    final from = series.first.day;
    final inRange = _weights.where((w) => !w.key.isBefore(from)).toList();
    final dw = inRange.length >= 2 ? inRange.last.value - inRange.first.value : null;
    final diff = _prevAvg > 0 ? avg - _prevAvg : null;
    String sign(double v) => v > 0 ? '+${v.toStringAsFixed(v.abs() < 10 ? 1 : 0)}' : v.toStringAsFixed(v.abs() < 10 ? 1 : 0);
    Widget row(IconData i, Color c, String k, String v) => Padding(
          padding: EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Icon(i, size: 20, color: c),
            SizedBox(width: 10),
            Expanded(child: Text(k)),
            Text(v, style: TextStyle(fontWeight: FontWeight.w700)),
          ]),
        );
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.insights_rounded, color: AppColors.rose),
          SizedBox(width: 8),
          Text(_days == 7 ? s['st_report_week'] : s['st_report_month'],
              style: Theme.of(context).textTheme.titleMedium),
        ]),
        SizedBox(height: 8),
        row(Icons.event_available_rounded, AppColors.lavender, s['st_tracked'],
            '${tracked.length} / ${series.length}'),
        row(Icons.flag_rounded, AppColors.mint, s['st_on_target'], '$onTarget'),
        row(Icons.arrow_upward_rounded, AppColors.peach, s['st_highest'],
            '${hi.kcal.round()} ${s['kcal']} · ${df.format(hi.day)}'),
        row(Icons.arrow_downward_rounded, AppColors.lavender, s['st_lowest'],
            '${lo.kcal.round()} ${s['kcal']} · ${df.format(lo.day)}'),
        if (diff != null)
          row(Icons.compare_arrows_rounded, AppColors.rose, s['st_vs_prev'],
              '${sign(diff)} ${s['kcal']}'),
        if (dw != null)
          row(Icons.monitor_weight_outlined, AppColors.rose, s['st_weight_change'], '${sign(dw)} kg'),
        if (tracked.length >= 3 && avg < Settings.instance.minSafeGoal * 0.85) ...[
          SizedBox(height: 6),
          Text(s['st_low_warn'],
              style: TextStyle(color: AppColors.peach, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ]),
    );
  }

  Widget _macroCard(S s, int trackedDays) {
    final st = Settings.instance;
    final n = trackedDays == 0 ? 1 : trackedDays;
    final p = _entries.fold(0.0, (a, e) => a + e.protein) / n;
    final c = _entries.fold(0.0, (a, e) => a + e.carbs) / n;
    final f = _entries.fold(0.0, (a, e) => a + e.fat) / n;
    return SoftCard(
      padding: EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        MacroRing(label: s['protein'], value: p, target: st.proteinTarget, color: AppColors.protein),
        MacroRing(label: s['carbs'], value: c, target: st.carbsTarget, color: AppColors.carbs),
        MacroRing(label: s['fat'], value: f, target: st.fatTarget, color: AppColors.fat),
      ]),
    );
  }

  Widget _waterCard(S s, List<DaySummary> series, String lang) {
    final goal = Settings.instance.waterGoal.toDouble();
    final vals = [for (final d in series) (_waterMap[AppDb.dayKey(d.day)] ?? 0).toDouble()];
    final maxY = ([goal, ...vals].reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble();
    final days = vals.where((v) => v > 0).length;
    final avgW = days == 0 ? 0.0 : vals.fold(0.0, (a, b) => a + b) / days;
    return SoftCard(
      padding: EdgeInsetsDirectional.fromSTEB(8, 16, 16, 8),
      child: Column(children: [
        Padding(
          padding: EdgeInsetsDirectional.only(start: 8, bottom: 10),
          child: Row(children: [
            Icon(Icons.water_drop_rounded, color: AppColors.lavender, size: 20),
            SizedBox(width: 6),
            Expanded(
              child: Text(s.f('st_water_avg', {'n': avgW.toStringAsFixed(1), 'g': goal.round()}),
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        SizedBox(
          height: 150,
          child: BarChart(BarChartData(
            maxY: maxY,
            gridData: FlGridData(show: false),
            borderData: FlBorderData(show: false),
            extraLinesData: ExtraLinesData(horizontalLines: [
              HorizontalLine(y: goal, color: AppColors.lavender, strokeWidth: 1.5, dashArray: [6, 4]),
            ]),
            titlesData: FlTitlesData(
              topTitles: AxisTitles(),
              rightTitles: AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) =>
                        Text('${v.round()}', style: TextStyle(fontSize: 10, color: AppColors.inkSoft))),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= series.length) return SizedBox();
                    if (_days == 30 && i % 5 != 0) return SizedBox();
                    final d = series[i].day;
                    return Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(_days == 7 ? DateFormat.E(lang).format(d) : DateFormat.d(lang).format(d),
                          style: TextStyle(fontSize: 10, color: AppColors.inkSoft)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < vals.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: vals[i],
                    width: _days == 7 ? 16 : 5,
                    borderRadius: BorderRadius.circular(5),
                    color: vals[i] >= goal ? AppColors.lavender : AppColors.lavenderSoft,
                  ),
                ]),
            ],
          )),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) =>
      SoftCard(
        child: Row(
          children: [
            Icon(icon, color: color),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      );
}
