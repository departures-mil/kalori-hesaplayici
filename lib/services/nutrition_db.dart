import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

import '../data/models.dart';
import 'food_db.dart';

/// One row of the USDA SR28 table (per 100 g).
class UsdaFood {
  final String desc;
  final double kcal, protein, carbs, fat;
  final double householdG;
  final String householdDesc;
  final List<String> tokens;
  UsdaFood(this.desc, this.kcal, this.protein, this.carbs, this.fat,
      this.householdG, this.householdDesc)
      : tokens = NutritionDb.tokens(desc);
}

List<UsdaFood> _parseUsda(String raw) {
  final j = jsonDecode(raw) as Map<String, dynamic>;
  return [
    for (final r in (j['foods'] as List))
      UsdaFood(
        r[0] as String,
        (r[1] as num).toDouble(),
        (r[2] as num).toDouble(),
        (r[3] as num).toDouble(),
        (r[4] as num).toDouble(),
        (r[5] as num).toDouble(),
        r[6] as String,
      )
  ];
}

/// v1.0.11: the AI only says WHAT is on the plate and HOW MUCH (grams);
/// calories come from verified tables:
///   1) foods.json — Turkish / Arab dishes and basics (tr/en/ar)
///   2) USDA SR28 — ~8,500 foods (English)
///   3) only if nothing matches: the AI's own per-100 g estimate.
/// The same photo therefore always gives the same numbers.
class NutritionDb {
  NutritionDb._();
  static final NutritionDb instance = NutritionDb._();

  List<UsdaFood> usda = [];
  Future<void>? _loading;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/usda.json');
      usda = await compute(_parseUsda, raw);
    } catch (_) {
      usda = [];
    }
  }

  static const _stop = {
    'and', 'with', 'or', 'the', 'of', 'a', 'in', 'ns', 'as', 'to', 'nfs',
    'from', 'without', 'type', 'style', 'made', 'commercial', 'regular',
  };

  static List<String> tokens(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 1 && !_stop.contains(w))
      .map((w) => w.length > 3 && w.endsWith('s') ? w.substring(0, w.length - 1) : w)
      .toList();

  /// Best USDA row for an English description; null if not close enough.
  UsdaFood? matchUsda(String q) {
    final qt = tokens(q).toSet();
    if (qt.isEmpty || usda.isEmpty) return null;
    UsdaFood? best;
    var bestScore = 0.0;
    for (final f in usda) {
      final ft = f.tokens;
      if (ft.isEmpty) continue;
      var common = 0;
      for (final t in qt) {
        if (ft.contains(t)) common++;
      }
      if (common == 0) continue;
      final cover = common / qt.length; // how much of the query is found
      final extra = (ft.toSet().length - common) / ft.length; // noise
      var score = cover - extra * 0.35;
      if (ft.first == qt.first) score += 0.15; // same main food
      if (score > bestScore) {
        bestScore = score;
        best = f;
      }
    }
    return bestScore >= 0.75 ? best : null;
  }

  /// Replaces the AI's nutrition guesses with table values when a reliable
  /// match exists. Keeps the AI's grams, range and cooking info.
  void resolve(FoodItem it, {List<String?>? names, List<String?>? usdaNames}) {
    final db = FoodDb.instance;
    Food? food;
    var score = 0;
    for (final q in names ?? [it.name, it.nameEn]) {
      if (q == null || q.trim().isEmpty) continue;
      final m = db.scoredMatch(q);
      if (m != null && m.$2 > score) {
        food = m.$1;
        score = m.$2;
      }
    }
    if (food != null && score >= 67 && _plausible(food.kcal, it.kcalPer100)) {
      it
        ..kcalPer100 = food.kcal
        ..proteinPer100 = food.protein
        ..carbsPer100 = food.carbs
        ..fatPer100 = food.fat
        ..foodId = food.id
        ..dataSource = 'db';
      return;
    }
    for (final en in usdaNames ?? [it.nameEn]) {
      if (en == null || en.trim().isEmpty) continue;
      final u = matchUsda(en);
      if (u != null && _plausible(u.kcal, it.kcalPer100)) {
        it
          ..kcalPer100 = u.kcal
          ..proteinPer100 = u.protein
          ..carbsPer100 = u.carbs
          ..fatPer100 = u.fat
          ..dataSource = 'usda';
        return;
      }
    }
    it.dataSource ??= 'ai';
  }

  /// A table value 2.5x away from the AI's estimate is most likely a wrong
  /// match (e.g. "chips" -> potato vs. chocolate chips): don't use it.
  static bool _plausible(double table, double ai) {
    if (ai <= 0) return true;
    if (table <= 5 && ai <= 15) return true; // water, tea…
    final r = table / ai;
    return r > 0.4 && r < 2.5;
  }

  /// USDA rows containing the query (manual search, English).
  List<UsdaFood> search(String q, {int limit = 40}) {
    final qt = tokens(q);
    if (qt.isEmpty) return [];
    final out = <UsdaFood>[];
    for (final f in usda) {
      if (qt.every((t) => f.tokens.any((x) => x.startsWith(t)))) {
        out.add(f);
        if (out.length >= limit) break;
      }
    }
    return out;
  }
}
