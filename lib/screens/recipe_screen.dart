import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import '../widgets/common.dart';
import 'manual_add_screen.dart';

/// 1.1.1 — Tarif oluşturucu: malzemeleri gir, porsiyon sayısını (ve istersen
/// pişmiş ağırlığı) yaz; uygulama porsiyon başına kaloriyi hesaplar.
class RecipeScreen extends StatefulWidget {
  final SavedMeal? recipe;
  const RecipeScreen({super.key, this.recipe});

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  late final _name = TextEditingController(text: widget.recipe?.name ?? '');
  late final _servings =
      TextEditingController(text: _fmt(widget.recipe?.servings ?? 4));
  late final _cooked = TextEditingController(
      text: (widget.recipe?.cooked ?? 0) > 0 ? '${widget.recipe!.cooked.round()}' : '');
  late List<FoodItem> _items =
      widget.recipe?.items.map((i) => FoodItem.fromJson(i.toJson())).toList() ?? [];

  static String _fmt(double v) => v % 1 == 0 ? '${v.round()}' : v.toStringAsFixed(1);

  @override
  void dispose() {
    _name.dispose();
    _servings.dispose();
    _cooked.dispose();
    super.dispose();
  }

  double get _serv => double.tryParse(_servings.text.replaceAll(',', '.')) ?? 1;
  double get _cookedG => double.tryParse(_cooked.text.replaceAll(',', '.')) ?? 0;

  SavedMeal get _draft => SavedMeal(
        uid: widget.recipe?.uid,
        kind: 'recipe',
        name: _name.text.trim(),
        items: _items,
        servings: _serv <= 0 ? 1 : _serv,
        cooked: _cookedG < 0 ? 0 : _cookedG,
        uses: widget.recipe?.uses ?? 0,
      );

  Future<void> _add() async {
    final it = await Navigator.push<FoodItem>(
        context, MaterialPageRoute(builder: (_) => const ManualAddScreen(pickOnly: true)));
    if (it != null) setState(() => _items = [..._items, it..confirmed = true]);
  }

  Future<void> _editGrams(int i) async {
    final s = S.of(context);
    final c = TextEditingController(text: '${_items[i].grams.round()}');
    final g = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_items[i].name),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: s['grams'], suffixText: 'g'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s['cancel'])),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, double.tryParse(c.text.replaceAll(',', '.'))),
              child: Text(s['ok'])),
        ],
      ),
    );
    if (g != null && g > 0) setState(() => _items[i].grams = g);
  }

  Future<void> _save() async {
    final s = S.of(context);
    if (_name.text.trim().isEmpty) {
      showSnack(context, s['rc_need_name']);
      return;
    }
    if (_items.isEmpty) {
      showSnack(context, s['rc_need_items']);
      return;
    }
    await AppDb.instance.saveSaved(_draft);
    if (!mounted) return;
    showSnack(context, s['saved']);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = _draft;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? s['rc_new'] : s['rc_edit']),
        actions: [
          IconButton(tooltip: s['save'], onPressed: _save, icon: const Icon(Icons.check_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: s['rc_name'], prefixIcon: const Icon(Icons.soup_kitchen_rounded)),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _servings,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: s['rc_servings']),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _cooked,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: s['rc_cooked'], suffixText: 'g'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(s['rc_cooked_hint'], style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          GradientCard(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['rc_per'], style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                  Text('${d.perServingKcal.round()} ${s['kcal']}',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                  Text('${d.perServingGrams.round()} g',
                      style: const TextStyle(color: Colors.white70)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${s['rc_total']}: ${d.kcal.round()} ${s['kcal']}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text('${d.totalGrams.round()} g', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Text(
                    s.f('rc_macros', {
                      'p': (d.protein / d.servings).round(),
                      'c': (d.carbs / d.servings).round(),
                      'f': (d.fat / d.servings).round(),
                    }),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ]),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Text(s['rc_ingredients'], style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton.icon(onPressed: _add, icon: const Icon(Icons.add_rounded), label: Text(s['rc_add'])),
          ]),
          if (_items.isEmpty)
            EmptyState(icon: Icons.egg_alt_outlined, title: s['rc_no_items'], action: s['rc_add'], onAction: _add),
          for (var i = 0; i < _items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 4, 8),
                child: Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _editGrams(i),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_items[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${_items[i].grams.round()} g  •  ${_items[i].kcal.round()} ${s['kcal']}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                  ),
                  IconButton(
                    tooltip: s['sv_remove'],
                    onPressed: () => setState(() => _items = [..._items]..removeAt(i)),
                    icon: Icon(Icons.close_rounded, color: AppColors.inkSoft),
                  ),
                ]),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.save_rounded),
        label: Text(s['save']),
      ),
    );
  }
}
