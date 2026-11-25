import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/db.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import '../widgets/common.dart';
import 'recipe_screen.dart';
import 'result_screen.dart';

/// 1.1.1 — Favoriler, sık yenenler ve tariflerim (tek dokunuşla ekle).
class SavedScreen extends StatefulWidget {
  final int initialTab;
  const SavedScreen({super.key, this.initialTab = 0});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<SavedMeal> _favs = [];
  List<SavedMeal> _recipes = [];
  List<(FoodItem, int)> _freq = [];
  bool _loaded = false;
  bool _added = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = await AppDb.instance.savedList('fav');
    final r = await AppDb.instance.savedList('recipe');
    final q = await AppDb.instance.frequentItems();
    if (!mounted) return;
    setState(() {
      _favs = f;
      _recipes = r;
      _freq = q;
      _loaded = true;
    });
  }

  Future<void> _open(List<FoodItem> items, {String? uid}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          result: AnalysisResult(
              items: items.map((i) => FoodItem.fromJson(i.toJson())..confirmed = true).toList(),
              source: AnalysisSource.manual),
        ),
      ),
    );
    if (ok == true) {
      if (uid != null) await AppDb.instance.useSaved(uid);
      _added = true;
      _load();
    }
  }

  Future<void> _useRecipe(SavedMeal r) async {
    final s = S.of(context);
    var n = 1.0;
    final grams = await showModalBottomSheet<double>(
      context: context,
      useSafeArea: true,
      builder: (c) => StatefulBuilder(builder: (c, set) {
        final g = n * r.perServingGrams;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(r.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(s.f('rc_per_serving', {'k': r.perServingKcal.round(), 'g': r.perServingGrams.round()}),
                style: Theme.of(c).textTheme.bodySmall),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton.filledTonal(
                  tooltip: '−',
                  onPressed: n <= 0.5 ? null : () => set(() => n -= 0.5),
                  icon: const Icon(Icons.remove_rounded)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text('${n.toStringAsFixed(n % 1 == 0 ? 0 : 1)} ${s['rc_serving']}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              IconButton.filledTonal(
                  tooltip: '+', onPressed: () => set(() => n += 0.5), icon: const Icon(Icons.add_rounded)),
            ]),
            const SizedBox(height: 8),
            Text('= ${g.round()} g  •  ${(n * r.perServingKcal).round()} ${s['kcal']}',
                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(c, g), child: Text(s['ok'])),
          ]),
        );
      }),
    );
    if (grams == null || grams <= 0) return;
    await _open([r.asFoodItem(grams)], uid: r.uid);
  }

  Future<void> _remove(SavedMeal m) async {
    final s = S.of(context);
    await AppDb.instance.removeSaved(m.uid!);
    if (!mounted) return;
    showSnack(context, s['sv_removed']);
    _load();
  }

  Future<void> _editRecipe([SavedMeal? r]) async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => RecipeScreen(recipe: r)));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.pop(context, _added);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(s['sv_title']),
            bottom: TabBar(tabs: [
              Tab(icon: const Icon(Icons.star_rounded), text: s['sv_favs']),
              Tab(icon: const Icon(Icons.history_rounded), text: s['sv_freq']),
              Tab(icon: const Icon(Icons.menu_book_rounded), text: s['sv_recipes']),
            ]),
          ),
          floatingActionButton: Builder(
            builder: (c) => FloatingActionButton.extended(
              onPressed: () {
                DefaultTabController.of(c).animateTo(2);
                _editRecipe();
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(s['rc_new']),
            ),
          ),
          body: !_loaded
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(children: [
                  _list(
                    _favs.isEmpty,
                    EmptyState(icon: Icons.star_outline_rounded, title: s['sv_favs_empty'], text: s['sv_favs_hint']),
                    [
                      for (final f in _favs)
                        _tile(
                          icon: Icons.star_rounded,
                          title: f.name,
                          sub: f.items.map((e) => e.name).join(', '),
                          kcal: f.kcal,
                          onTap: () => _open(f.items, uid: f.uid),
                          onDelete: () => _remove(f),
                        ),
                    ],
                  ),
                  _list(
                    _freq.isEmpty,
                    EmptyState(icon: Icons.history_rounded, title: s['sv_freq_empty']),
                    [
                      for (final q in _freq)
                        _tile(
                          icon: Icons.restaurant_rounded,
                          title: q.$1.name,
                          sub: s.f('sv_times', {'n': q.$2, 'g': q.$1.grams.round()}),
                          kcal: q.$1.kcal,
                          onTap: () => _open([q.$1]),
                        ),
                    ],
                  ),
                  _list(
                    _recipes.isEmpty,
                    EmptyState(
                        icon: Icons.soup_kitchen_rounded,
                        title: s['rc_empty'],
                        text: s['rc_empty_hint'],
                        action: s['rc_new'],
                        onAction: () => _editRecipe()),
                    [
                      for (final r in _recipes)
                        _tile(
                          icon: Icons.soup_kitchen_rounded,
                          title: r.name,
                          sub: s.f('rc_per_serving', {'k': r.perServingKcal.round(), 'g': r.perServingGrams.round()}),
                          kcal: r.perServingKcal,
                          onTap: () => _useRecipe(r),
                          onEdit: () => _editRecipe(r),
                          onDelete: () => _remove(r),
                        ),
                    ],
                  ),
                ]),
        ),
      ),
    );
  }

  Widget _list(bool empty, Widget emptyW, List<Widget> children) => RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
          children: empty ? [emptyW] : children,
        ),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    required String sub,
    required double kcal,
    required VoidCallback onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SoftCard(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 4, 10),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: AppColors.roseSoft.withValues(alpha: 0.3), shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.rose, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            const SizedBox(width: 8),
            Text('${kcal.round()} ${s['kcal']}',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.rose)),
            if (onEdit != null || onDelete != null)
              PopupMenuButton<String>(
                tooltip: s['sv_more'],
                onSelected: (v) {
                  if (v == 'e') {
                    onEdit?.call();
                  } else {
                    onDelete?.call();
                  }
                },
                itemBuilder: (_) => [
                  if (onEdit != null) PopupMenuItem(value: 'e', child: Text(s['rc_edit'])),
                  if (onDelete != null) PopupMenuItem(value: 'd', child: Text(s['sv_remove'])),
                ],
              )
            else
              const SizedBox(width: 12),
          ]),
        ),
      ),
    );
  }
}
