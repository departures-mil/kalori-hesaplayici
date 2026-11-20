import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../data/settings.dart';
import '../l10n/strings.dart';
import '../services/food_db.dart';
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
            const SizedBox(height: 10),
            TextField(
                controller: kcal,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: s['calories_per_100'])),
            const SizedBox(height: 10),
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
    return Scaffold(
      appBar: AppBar(title: Text(s['manual_add'])),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: s['search_food'],
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final f = list[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _choose(FoodItem.fromFood(f, lang)),
                    child: SoftCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.name(lang),
                                    style: const TextStyle(
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
                              style: const TextStyle(
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
        icon: const Icon(Icons.add),
        label: Text(s['manual_add']),
      ),
    );
  }
}
