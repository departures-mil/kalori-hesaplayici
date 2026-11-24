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

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final d = await AppDb.instance.dailyTotals(days: _days);
    final w = await AppDb.instance.weights();
    final l = await AppDb.instance.lifetimeStats();
    if (!mounted) return;
    setState(() {
      _data = d;
      _weights = w;
      _life = l;
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
