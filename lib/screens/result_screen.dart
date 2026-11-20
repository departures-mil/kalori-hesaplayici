import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/theme.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../data/settings.dart';
import '../l10n/strings.dart';
import '../services/online_analyzer.dart';
import '../widgets/common.dart';
import 'manual_add_screen.dart';

class ResultScreen extends StatefulWidget {
  final AnalysisResult result;
  final DiaryEntry? editing; // when editing an existing diary entry
  const ResultScreen({super.key, required this.result, this.editing});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late List<FoodItem> items;
  late MealType meal;
  late AnalysisSource source;
  String? imagePath;
  bool _saving = false;
  bool _reanalyzing = false;

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

  double get total => items.fold(0, (s, i) => s + i.kcal);

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
    if (items.isEmpty) return;
    setState(() => _saving = true);
    final path = await _persistImage();
    final e = DiaryEntry(
      id: widget.editing?.id,
      time: widget.editing?.time ?? DateTime.now(),
      meal: meal,
      items: items,
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
        setState(() {
          items = r.items;
          source = r.source;
        });
      }
    } catch (_) {
      if (mounted) showSnack(context, S.of(context)['error_analysis']);
    } finally {
      if (mounted) setState(() => _reanalyzing = false);
    }
  }

  Future<void> _addItem() async {
    final item = await Navigator.push<FoodItem>(
      context,
      MaterialPageRoute(builder: (_) => const ManualAddScreen(pickOnly: true)),
    );
    if (item != null) setState(() => items.add(item));
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
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _macro(s['protein'],
                        items.fold(0.0, (a, i) => a + i.protein)),
                    _macro(
                        s['carbs'], items.fold(0.0, (a, i) => a + i.carbs)),
                    _macro(s['fat'], items.fold(0.0, (a, i) => a + i.fat)),
                  ],
                ),
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
          if (items.isEmpty)
            SoftCard(child: Text(s['not_food'])),
          ...items.asMap().entries.map((e) => _ItemCard(
                item: e.value,
                onChanged: () => setState(() {}),
                onDelete: () => setState(() => items.removeAt(e.key)),
              )),
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
              !const ['no_internet', 'online_failed']
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
          onPressed: _saving || items.isEmpty ? null : _save,
          icon: const Icon(Icons.bookmark_added_rounded),
          label: Text(widget.editing == null ? s['add_to_diary'] : s['save']),
        ),
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

class _ItemCard extends StatefulWidget {
  final FoodItem item;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  const _ItemCard(
      {required this.item, required this.onChanged, required this.onDelete});

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  late final double base = widget.item.grams; // "medium" portion

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                Text('${item.kcal.round()} ${s['kcal']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.rose)),
                IconButton(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.inkSoft)),
              ],
            ),
            Row(
              children: [
                Text('${s['portion']}: ${item.grams.round()} ${s['grams']}',
                    style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                if (item.confidence < 1)
                  Text(
                      '${s['confidence']}: ${(item.confidence * 100).round()}%',
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            Slider(
              value: item.grams.clamp(5, 1000),
              min: 5,
              max: 1000,
              divisions: 199,
              activeColor: AppColors.rose,
              onChanged: (v) {
                item.grams = v.roundToDouble();
                widget.onChanged();
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
          ],
        ),
      ),
    );
  }

  Widget _portionBtn(String label, double mult) => InkWell(
        onTap: () {
          widget.item.grams = (base * mult).roundToDouble().clamp(5, 1000);
          widget.onChanged();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: AppColors.lavenderSoft.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10)),
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
      );
}
