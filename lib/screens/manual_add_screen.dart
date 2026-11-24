import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../data/settings.dart';
import '../l10n/strings.dart';
import '../services/food_db.dart';
import '../services/nutrition_db.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

/// Search the local food table or type a custom food.
/// With [pickOnly], returns a FoodItem instead of opening the result screen.
class ManualAddScreen extends StatefulWidget {
  final bool pickOnly;
  const ManualAddScreen({super.key, this.pickOnly = false});

  @override
  State<ManualAddScreen> createState() => _ManualAddScreenState();
}

class _ManualAddScreenState extends State<ManualAddScreen> {
  String _q = '';

  @override
  void initState() {
    super.initState();
    NutritionDb.instance.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  /// Asks how much: number + unit (gram, portion, slice, ladle, spoon…).
  Future<double?> _amount(String title, double portion,
      Map<String, double> units) async {
    final s = S.of(context);
    final opts = <String, double>{'portion': portion, ...units, 'g': 1};
    var unit = 'portion';
    final ctrl = TextEditingController(text: '1');
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => StatefulBuilder(builder: (c, set) {
        final n = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
        final g = n * (opts[unit] ?? 1);
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType:
                    TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: s['amount']),
                onChanged: (_) => set(() {}),
              ),
              SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (final e in opts.entries)
                  ChoiceChip(
                    label: Text(e.key == 'g'
                        ? s['unit_g']
                        : '${s['unit_${e.key}']} (${e.value.round()} g)'),
                    selected: unit == e.key,
                    selectedColor: AppColors.roseSoft,
                    onSelected: (_) => set(() {
                      if (e.key == 'g' && unit != 'g') {
                        ctrl.text = '${g.round()}';
                      } else if (e.key != 'g' && unit == 'g') {
                        ctrl.text = '1';
                      }
                      unit = e.key;
                    }),
                  ),
              ]),
              SizedBox(height: 12),
              Text('= ${g.round()} g',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              SizedBox(height: 12),
              FilledButton(
                onPressed: g > 0 ? () => Navigator.pop(c, g) : null,
                child: Text(s['ok']),
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _pickFood(Food f, String lang) async {
    final g = await _amount(f.name(lang), f.portion, FoodDb.defaultUnits(f));
    if (g == null || !mounted) return;
    _choose(FoodItem.fromFood(f, lang, grams: g.roundToDouble())
      ..confirmed = true);
  }

  Future<void> _pickUsda(UsdaFood u) async {
    final units = <String, double>{};
    final g = await _amount(u.desc, u.householdG > 0 ? u.householdG : 100, units);
    if (g == null || !mounted) return;
    _choose(FoodItem(
      name: u.desc,
      nameEn: u.desc,
      grams: g.roundToDouble(),
      kcalPer100: u.kcal,
      proteinPer100: u.protein,
      carbsPer100: u.carbs,
      fatPer100: u.fat,
      dataSource: 'usda',
      confirmed: true,
    ));
  }

  Future<void> _choose(FoodItem item) async {
    if (widget.pickOnly) {
      Navigator.pop(context, item);
      return;
    }
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          result:
              AnalysisResult(items: [item], source: AnalysisSource.manual),
        ),
      ),
    );
    if (added == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _custom() async {
    final s = S.of(context);
    final name = TextEditingController();
    final kcal = TextEditingController();
    final grams = TextEditingController(text: '100');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s['manual_add']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration: InputDecoration(labelText: s['name'])),
            SizedBox(height: 10),
            TextField(
                controller: kcal,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: s['calories_per_100'])),
            SizedBox(height: 10),
            TextField(
                controller: grams,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: s['grams'])),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(s['cancel'])),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(s['ok'])),
        ],
      ),
    );
    if (ok != true) return;
    final k = double.tryParse(kcal.text.replaceAll(',', '.')) ?? 0;
    final g = double.tryParse(grams.text.replaceAll(',', '.')) ?? 100;
    if (name.text.trim().isEmpty) return;
    _choose(FoodItem(name: name.text.trim(), grams: g, kcalPer100: k));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = Settings.instance.lang;
    final list = FoodDb.instance.search(_q, lang);
    final usda = _q.trim().length >= 3
        ? NutritionDb.instance.search(_q)
        : <UsdaFood>[];
    return Scaffold(
      appBar: AppBar(title: Text(s['manual_add'])),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: s['search_food'],
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 100),
              itemCount: list.length + (usda.isEmpty ? 0 : usda.length + 1),
              itemBuilder: (_, i) {
                if (i >= list.length) {
                  final j = i - list.length;
                  if (j == 0) {
                    return Padding(
                      padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
                      child: Text(s['usda_section'],
                          style: Theme.of(context).textTheme.titleSmall),
                    );
                  }
                  final u = usda[j - 1];
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _pickUsda(u),
                      child: SoftCard(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(children: [
                          Expanded(
                              child: Text(u.desc,
                                  style: TextStyle(fontSize: 13))),
                          SizedBox(width: 8),
                          Text('${u.kcal.round()} ${s['kcal']}/100 g',
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                      ),
                    ),
                  );
                }
                final f = list[i];
                return Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _pickFood(f, lang),
                    child: SoftCard(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.name(lang),
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Text(
                                    '${f.kcal.round()} ${s['kcal']} / 100 g  •  ${f.portion.round()} g',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                              ],
                            ),
                          ),
                          Text(
                              '${(f.kcal * f.portion / 100).round()} ${s['kcal']}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.rose)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _custom,
        backgroundColor: AppColors.rose,
        foregroundColor: Colors.white,
        icon: Icon(Icons.add),
        label: Text(s['manual_add']),
      ),
    );
  }
}
