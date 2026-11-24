import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/theme.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../data/settings.dart';
import '../l10n/strings.dart';
import '../services/food_db.dart';
import '../services/online_analyzer.dart';
import '../services/portion_learner.dart';
import '../widgets/common.dart';
import 'manual_add_screen.dart';

/// Result + confirmation screen (v1.0.11): every item can be confirmed or
/// corrected (grams, cooking style, oil), hidden calories can be added, and
/// the total is shown as a range with a confidence level.
class ResultScreen extends StatefulWidget {
  final AnalysisResult result;
  final DiaryEntry? editing; // when editing an existing diary entry
  const ResultScreen({super.key, required this.result, this.editing});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

/// "Hidden calories": things a photo usually does not show.
class _Hidden {
  final String key, foodId;
  final String unit; // household unit used for one step
  const _Hidden(this.key, this.foodId, this.unit);
}

const _hidden = [
  _Hidden('hidden_bread', 'ekmek_dilim', 'slice'),
  _Hidden('hidden_sugar', 'sugar_cube', 'piece'),
  _Hidden('hidden_oil', 'olive_oil', 'tbsp'),
  _Hidden('hidden_sauce', 'salad_dressing', 'tbsp'),
];

class _ResultScreenState extends State<ResultScreen> {
  late List<FoodItem> items;
  late MealType meal;
  late AnalysisSource source;
  String? imagePath;
  bool _saving = false;
  bool _reanalyzing = false;
  final Map<String, int> _extra = {};

  bool get _analysed =>
      source == AnalysisSource.ai || source == AnalysisSource.offline;

  @override
  void initState() {
    super.initState();
    items = widget.result.items
        .map((i) => FoodItem.fromJson(i.toJson()))
        .toList();
    source = widget.result.source;
    imagePath = widget.result.imagePath;
    meal = widget.editing?.meal ?? _guessMeal();
  }

  static MealType _guessMeal() {
    final h = DateTime.now().hour;
    if (h < 11) return MealType.breakfast;
    if (h < 15) return MealType.lunch;
    if (h < 18) return MealType.snack;
    return MealType.dinner;
  }

  /// Hidden-calorie lines as food items.
  List<FoodItem> _extraItems(String lang) {
    final out = <FoodItem>[];
    for (final h in _hidden) {
      final n = _extra[h.key] ?? 0;
      if (n <= 0) continue;
      final f = FoodDb.instance.byId(h.foodId);
      if (f == null) continue;
      out.add(FoodItem.fromFood(f, lang,
          grams: n * FoodDb.unitGrams(f, h.unit))
        ..confirmed = true
        ..dataSource = 'user');
    }
    return out;
  }

  List<FoodItem> get _all => [...items, ..._extraItems(Settings.instance.lang)];
  double get total => _all.fold(0, (s, i) => s + i.kcal);
  double get totalMin => _all.fold(0, (s, i) => s + i.kcalMin);
  double get totalMax => _all.fold(0, (s, i) => s + i.kcalMax);

  /// Calorie-weighted confidence of the meal (confirmed items count as 1).
  double get confidence {
    final all = _all;
    final t = all.fold(0.0, (s, i) => s + i.kcal);
    if (t <= 0) return all.isEmpty ? 0 : 1;
    return all.fold(
            0.0, (s, i) => s + (i.confirmed ? 1.0 : i.confidence) * i.kcal) /
        t;
  }

  Future<String?> _persistImage() async {
    if (imagePath == null) return null;
    final src = File(imagePath!);
    if (!await src.exists()) return null;
    final dir = await getApplicationDocumentsDirectory();
    final imgDir = Directory(p.join(dir.path, 'photos'));
    await imgDir.create(recursive: true);
    if (p.isWithin(imgDir.path, src.path)) return src.path;
    final dst = File(p.join(
        imgDir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg'));
    // store a downscaled copy to save space
    final bytes = await OnlineAnalyzer.prepareImage(src);
    await dst.writeAsBytes(bytes);
    return dst.path;
  }

  Future<void> _save() async {
    final s = S.of(context);
    final all = _all;
    if (all.isEmpty) return;
    setState(() => _saving = true);
    if (_analysed && widget.editing == null) {
      await PortionLearner.instance.record(items);
    }
    final path = await _persistImage();
    final e = DiaryEntry(
      id: widget.editing?.id,
      time: widget.editing?.time ?? DateTime.now(),
      meal: meal,
      items: all,
      source: source,
      imagePath: path,
      note: widget.result.note,
    );
    if (widget.editing == null) {
      await AppDb.instance.insertEntry(e);
    } else {
      await AppDb.instance.updateEntry(e);
    }
    if (!mounted) return;
    showSnack(context, s['added']);
    Navigator.pop(context, true);
  }

  Future<void> _reanalyze() async {
    if (imagePath == null) return;
    setState(() => _reanalyzing = true);
    try {
      final r = await OnlineAnalyzer.analyze(
          File(imagePath!), Settings.instance.lang);
      if (r != null && mounted) {
        PortionLearner.instance.apply(r.items,
            userListed: (widget.result.hint ?? '').isNotEmpty);
        setState(() {
          items = r.items;
          source = r.source;
        });
      }
    } catch (e) {
      if (mounted) {
        final err = OnlineAnalyzer.toAiError(e, '-');
        showSnack(context, '${S.of(context)[err.key]}\n(${err.detail})');
      }
    } finally {
      if (mounted) setState(() => _reanalyzing = false);
    }
  }

  Future<void> _addItem() async {
    final item = await Navigator.push<FoodItem>(
      context,
      MaterialPageRoute(builder: (_) => const ManualAddScreen(pickOnly: true)),
    );
    if (item != null) setState(() => items.add(item..confirmed = true));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final img = imagePath == null ? null : File(imagePath!);
    final sourceLabel = switch (source) {
      AnalysisSource.ai => s['source_ai'],
      AnalysisSource.offline => s['source_offline'],
      AnalysisSource.barcode => s['source_barcode'],
      AnalysisSource.manual => s['source_manual'],
    };
    final conf = confidence;
    final lo = totalMin.round(), hi = totalMax.round();
    final showRange = _analysed && hi - lo >= 10;
    final unsure = items
        .where((i) =>
            !i.confirmed && (i.question != null || i.confidence < 0.6))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(s['result'])),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          if (img != null && img.existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.file(img, height: 220, fit: BoxFit.cover),
            ),
          const SizedBox(height: 16),
          GradientCard(
            child: Column(
              children: [
                Text(s['total_calories'],
                    style: const TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w600)),
                Text('${total.round()}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w800)),
                Text(s['kcal'],
                    style: const TextStyle(color: Colors.white70)),
                if (showRange) ...[
                  const SizedBox(height: 4),
                  Text('${s['range_label']}: $lo – $hi ${s['kcal']}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _macro(
                        s['protein'], _all.fold(0.0, (a, i) => a + i.protein)),
                    _macro(s['carbs'], _all.fold(0.0, (a, i) => a + i.carbs)),
                    _macro(s['fat'], _all.fold(0.0, (a, i) => a + i.fat)),
                  ],
                ),
                if (_analysed) ...[
                  const SizedBox(height: 12),
                  _ConfidenceBar(value: conf, label: s['conf_label']),
                ],
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(sourceLabel,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ),
          if (source == AnalysisSource.offline && imagePath != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _reanalyzing ? null : _reanalyze,
              icon: _reanalyzing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_sync_rounded),
              label: Text(s['reanalyze_online']),
            ),
          ],
          if (_analysed && unsure.isNotEmpty) ...[
            const SizedBox(height: 14),
            SoftCard(
              color: AppColors.peach.withValues(alpha: 0.18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.help_outline_rounded,
                        color: AppColors.carbs),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s['check_title'],
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(s['check_sub'],
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  for (final u in unsure)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                          '• ${u.name}: ${u.question ?? s['ask_portion']}'),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Text(s['items_found'],
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_circle_rounded,
                      color: AppColors.rose, size: 28)),
            ],
          ),
          if (items.isEmpty) SoftCard(child: Text(s['not_food'])),
          ...items.asMap().entries.map((e) => _ItemCard(
                key: ObjectKey(e.value),
                item: e.value,
                detailed: _analysed,
                onChanged: () => setState(() {}),
                onDelete: () => setState(() => items.removeAt(e.key)),
              )),
          if (_analysed) ...[
            const SizedBox(height: 8),
            _hiddenCard(s),
          ],
          const SizedBox(height: 16),
          Text(s['meal'], style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: MealType.values
                .map((m) => ChoiceChip(
                      label: Text(s[m.name]),
                      selected: meal == m,
                      selectedColor: AppColors.roseSoft,
                      onSelected: (_) => setState(() => meal = m),
                    ))
                .toList(),
          ),
          if (widget.result.note != null &&
              widget.result.note!.isNotEmpty &&
              !const ['no_internet', 'online_failed', 'no_key']
                  .contains(widget.result.note)) ...[
            const SizedBox(height: 16),
            SoftCard(
                color: AppColors.lavenderSoft.withValues(alpha: 0.4),
                child: Text(widget.result.note!)),
          ],
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        color: AppColors.cream,
        child: FilledButton.icon(
          onPressed: _saving || _all.isEmpty ? null : _save,
          icon: const Icon(Icons.bookmark_added_rounded),
          label: Text(widget.editing == null ? s['add_to_diary'] : s['save']),
        ),
      ),
    );
  }

  Widget _hiddenCard(S s) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.visibility_off_rounded, color: AppColors.lavender),
            const SizedBox(width: 8),
            Text(s['hidden_title'],
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
          const SizedBox(height: 2),
          Text(s['hidden_sub'], style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          for (final h in _hidden)
            Builder(builder: (_) {
              final n = _extra[h.key] ?? 0;
              final f = FoodDb.instance.byId(h.foodId);
              final one = f == null
                  ? 0
                  : f.kcal * FoodDb.unitGrams(f, h.unit) / 100;
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s[h.key]),
                        Text(
                            '${one.round()} ${s['kcal']} × $n'
                            '${n > 0 ? ' = ${(one * n).round()} ${s['kcal']}' : ''}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                      onPressed: n > 0
                          ? () => setState(() => _extra[h.key] = n - 1)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline_rounded)),
                  Text('$n',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  IconButton(
                      onPressed: n < 20
                          ? () => setState(() => _extra[h.key] = n + 1)
                          : null,
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          color: AppColors.rose)),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _macro(String label, double g) => Column(children: [
        Text('${g.round()} g',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]);
}

class _ConfidenceBar extends StatelessWidget {
  final double value;
  final String label;
  const _ConfidenceBar({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0).toDouble();
    final color = v >= 0.75
        ? AppColors.mint
        : v >= 0.55
            ? AppColors.peach
            : Colors.redAccent;
    return Row(
      children: [
        Text('$label ${(v * 100).round()}%',
            style: const TextStyle(color: Colors.white, fontSize: 12)),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 8,
              color: color,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemCard extends StatefulWidget {
  final FoodItem item;
  final bool detailed; // photo analysis: show cooking / oil / confirm
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  const _ItemCard(
      {super.key,
      required this.item,
      required this.detailed,
      required this.onChanged,
      required this.onDelete});

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  late final double base = widget.item.grams; // "medium" portion

  static const _cooks = ['raw', 'boiled', 'grilled', 'baked', 'stewed', 'fried'];

  void _changed() {
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final item = widget.item;
    final src = switch (item.dataSource) {
      'db' => s['src_db'],
      'usda' => s['src_usda'],
      'ai' => s['src_ai'],
      _ => null,
    };
    final lo = item.kcalMin.round(), hi = item.kcalMax.round();
    final small = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.detailed)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      item.confirmed = !item.confirmed;
                      _changed();
                    },
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: Icon(
                          item.confirmed
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: item.confirmed
                              ? AppColors.mint
                              : AppColors.inkSoft),
                    ),
                  ),
                Expanded(
                  child: Text(item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${item.kcal.round()} ${s['kcal']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.rose)),
                    if (widget.detailed && hi - lo >= 5)
                      Text('$lo–$hi', style: small),
                  ],
                ),
                IconButton(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.inkSoft)),
              ],
            ),
            if (widget.detailed && item.question != null && !item.confirmed)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.peach.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.help_outline_rounded,
                      size: 16, color: AppColors.carbs),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(item.question!,
                          style: const TextStyle(fontSize: 13))),
                ]),
              ),
            Row(
              children: [
                Text('${s['portion']}: ${item.grams.round()} ${s['grams']}',
                    style: small),
                const Spacer(),
                if (src != null) ...[
                  _badge(src),
                  const SizedBox(width: 6),
                ],
                if (item.confidence < 1 && !item.confirmed)
                  Text('${s['confidence']}: ${(item.confidence * 100).round()}%',
                      style: small),
              ],
            ),
            if (item.learned)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  const Icon(Icons.auto_graph_rounded,
                      size: 14, color: AppColors.lavender),
                  const SizedBox(width: 4),
                  Expanded(child: Text(s['learned_note'], style: small)),
                ]),
              ),
            Slider(
              value: item.grams.clamp(5, 1500),
              min: 5,
              max: 1500,
              divisions: 299,
              activeColor: AppColors.rose,
              onChanged: (v) {
                item.grams = v.roundToDouble();
                _changed();
              },
            ),
            Row(
              children: [
                _portionBtn(s['small'], 0.6),
                const SizedBox(width: 6),
                _portionBtn(s['medium'], 1.0),
                const SizedBox(width: 6),
                _portionBtn(s['large'], 1.5),
                const Spacer(),
                MacroChip(
                    label: 'P', grams: item.protein, color: AppColors.protein),
                const SizedBox(width: 4),
                MacroChip(
                    label: 'C', grams: item.carbs, color: AppColors.carbs),
                const SizedBox(width: 4),
                MacroChip(label: 'F', grams: item.fat, color: AppColors.fat),
              ],
            ),
            if (widget.detailed) ...[
              const SizedBox(height: 10),
              Text(s['cook_title'], style: small),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final c in _cooks)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ChoiceChip(
                        label: Text(s['cook_$c']),
                        selected: (item.cook ?? item.cookBase) == c,
                        selectedColor: AppColors.roseSoft,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          item.cookBase ??=
                              FoodItem.guessCook('${item.nameEn ?? ''} ${item.name}');
                          item.cook = c;
                          _changed();
                        },
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 6),
              Text(s['oil_title'], style: small),
              const SizedBox(height: 4),
              Wrap(spacing: 6, children: [
                for (final o in const ['none', 'normal', 'high'])
                  ChoiceChip(
                    label: Text(s['oil_$o']),
                    selected: item.oil == o,
                    selectedColor: AppColors.roseSoft,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      item.oil = o;
                      _changed();
                    },
                  ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: AppColors.lavenderSoft.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: const TextStyle(fontSize: 11)),
      );

  Widget _portionBtn(String label, double mult) => InkWell(
        onTap: () {
          widget.item.grams = (base * mult).roundToDouble().clamp(5, 1500);
          _changed();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: AppColors.lavenderSoft.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10)),
          child: Text(label, style: const TextStyle(fontSize: 11)),
        ),
      );
}
