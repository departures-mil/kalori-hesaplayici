import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../data/settings.dart';
import '../l10n/strings.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

class DiaryScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const DiaryScreen({super.key, required this.onChanged});

  @override
  State<DiaryScreen> createState() => DiaryScreenState();
}

class DiaryScreenState extends State<DiaryScreen> {
  DateTime _day = DateTime.now();
  List<DiaryEntry> _entries = [];
  int _water = 0;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final e = await AppDb.instance.entriesForDay(_day);
    final w = await AppDb.instance.water(_day);
    if (!mounted) return;
    setState(() {
      _entries = e;
      _water = w;
    });
  }

  void _shift(int d) {
    setState(() => _day = _day.add(Duration(days: d)));
    refresh();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(Duration(days: 1)),
    );
    if (d != null) {
      setState(() => _day = d);
      refresh();
    }
  }

  Future<void> _delete(DiaryEntry e) async {
    await AppDb.instance.deleteEntry(e.id!);
    await refresh();
    widget.onChanged();
  }

  Future<void> _edit(DiaryEntry e) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          editing: e,
          result: AnalysisResult(
              items: e.items,
              source: e.source,
              imagePath: e.imagePath,
              note: e.note),
        ),
      ),
    );
    if (changed == true) {
      await refresh();
      widget.onChanged();
    }
  }

  /// 1.1.1: kayda uzun basınca — favorilere ekle / bugüne kopyala / sil.
  Future<void> _entryMenu(DiaryEntry e) async {
    final s = S.of(context);
    final isToday = AppDb.dayKey(_day) == AppDb.dayKey(DateTime.now());
    final v = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
            title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700))),
        ListTile(
            leading: Icon(Icons.star_rounded, color: AppColors.rose),
            title: Text(s['sv_add_fav']),
            onTap: () => Navigator.pop(c, 'fav')),
        ListTile(
            leading: Icon(Icons.content_copy_rounded, color: AppColors.lavender),
            title: Text(isToday ? s['cp_again'] : s['cp_to_today']),
            onTap: () => Navigator.pop(c, 'copy')),
        ListTile(
            leading: Icon(Icons.edit_rounded, color: AppColors.inkSoft),
            title: Text(s['rc_edit']),
            onTap: () => Navigator.pop(c, 'edit')),
        ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: AppColors.rose),
            title: Text(s['sv_remove']),
            onTap: () => Navigator.pop(c, 'del')),
        const SizedBox(height: 8),
      ]),
    );
    if (!mounted || v == null) return;
    switch (v) {
      case 'fav':
        await AppDb.instance.saveSaved(SavedMeal(
            kind: 'fav',
            name: e.items.map((i) => i.name).take(3).join(', '),
            items: e.items.map((i) => FoodItem.fromJson(i.toJson())..confirmed = true).toList()));
        if (mounted) showSnack(context, s['sv_fav_saved']);
      case 'copy':
        await AppDb.instance.insertEntry(DiaryEntry(
            time: DateTime.now(),
            meal: e.meal,
            items: e.items.map((i) => FoodItem.fromJson(i.toJson())).toList(),
            source: AnalysisSource.manual,
            note: e.note));
        if (mounted) showSnack(context, s['added']);
        await refresh();
        widget.onChanged();
      case 'edit':
        await _edit(e);
      case 'del':
        await _delete(e);
    }
  }

  /// 1.1.1: geçmiş bir günün öğününü bugüne kopyala.
  Future<void> _copyMeal(MealType m) async {
    final s = S.of(context);
    final n = await AppDb.instance.copyMeal(_day, m);
    if (!mounted) return;
    showSnack(context, s.f('cp_done', {'n': n}));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = Settings.instance.lang;
    final total = _entries.fold(0.0, (a, e) => a + e.kcal);
    final goal = Settings.instance.dailyGoal;
    final df = DateFormat.yMMMMEEEEd(lang);
    final isToday = AppDb.dayKey(_day) == AppDb.dayKey(DateTime.now());

    final byMeal = <MealType, List<DiaryEntry>>{};
    for (final e in _entries) {
      byMeal.putIfAbsent(e.meal, () => []).add(e);
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Row(
            children: [
              IconButton(
                  tooltip: s['dy_prev'],
                  onPressed: () => _shift(-1),
                  icon: Icon(Icons.chevron_left_rounded)),
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  child: Column(
                    children: [
                      Text(isToday ? s['today'] : df.format(_day),
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      if (isToday)
                        Text(df.format(_day),
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              IconButton(
                  tooltip: s['dy_next'],
                  onPressed: () => _shift(1),
                  icon: Icon(Icons.chevron_right_rounded)),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                SoftCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s['total_calories'],
                                style:
                                    Theme.of(context).textTheme.bodySmall),
                            Text('${total.round()} / $goal ${s['kcal']}',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.rose)),
                            SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: goal > 0
                                    ? (total / goal).clamp(0, 1)
                                    : 0,
                                minHeight: 8,
                                color: total > goal
                                    ? AppColors.peach
                                    : AppColors.rose,
                                backgroundColor: AppColors.lavenderSoft
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      Column(
                        children: [
                          Icon(Icons.water_drop_rounded,
                              color: AppColors.lavender),
                          Text('$_water',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700)),
                          Text(s['glasses'],
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    MacroChip(
                        label: s['protein'],
                        grams: _entries.fold(0.0, (a, e) => a + e.protein),
                        color: AppColors.protein),
                    MacroChip(
                        label: s['carbs'],
                        grams: _entries.fold(0.0, (a, e) => a + e.carbs),
                        color: AppColors.carbs),
                    MacroChip(
                        label: s['fat'],
                        grams: _entries.fold(0.0, (a, e) => a + e.fat),
                        color: AppColors.fat),
                  ],
                ),
                SizedBox(height: 16),
                if (_entries.isEmpty)
                  EmptyState(
                    icon: Icons.restaurant_menu_rounded,
                    title: s['no_entries'],
                    text: s['dy_empty_hint'],
                  ),
                for (final m in MealType.values)
                  if (byMeal.containsKey(m)) ...[
                    Padding(
                      padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
                      child: Row(
                        children: [
                          Text(s[m.name],
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          Spacer(),
                          Text(
                              '${byMeal[m]!.fold(0.0, (a, e) => a + e.kcal).round()} ${s['kcal']}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.inkSoft)),
                          if (!isToday)
                            IconButton(
                              tooltip: s['cp_to_today'],
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _copyMeal(m),
                              icon: Icon(Icons.content_copy_rounded,
                                  size: 18, color: AppColors.lavender),
                            ),
                        ],
                      ),
                    ),
                    ...byMeal[m]!.map((e) => _EntryTile(
                          entry: e,
                          onTap: () => _edit(e),
                          onLongPress: () => _entryMenu(e),
                          onDelete: () => _delete(e),
                        )),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;
  const _EntryTile(
      {required this.entry,
      required this.onTap,
      required this.onLongPress,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final f = entry.imagePath == null ? null : File(entry.imagePath!);
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
            color: AppColors.rose, borderRadius: BorderRadius.circular(18)),
        child: Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(18),
          child: SoftCard(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: f != null && f.existsSync()
                        ? Image.file(f, fit: BoxFit.cover)
                        : Container(
                            color: AppColors.roseSoft.withValues(alpha: 0.3),
                            child: Icon(
                                entry.source == AnalysisSource.barcode
                                    ? Icons.qr_code_rounded
                                    : Icons.restaurant_rounded,
                                color: AppColors.rose)),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontWeight: FontWeight.w600)),
                      Text(DateFormat.Hm().format(entry.time),
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Text('${entry.kcal.round()} ${s['kcal']}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.rose)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
