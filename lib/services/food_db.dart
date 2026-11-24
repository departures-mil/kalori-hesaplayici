import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/models.dart';

/// Local nutrition table. Loaded from the bundled asset, overridden by a
/// synced copy downloaded from GitHub (see SyncService).
class FoodDb {
  FoodDb._();
  static final FoodDb instance = FoodDb._();

  List<Food> foods = [];
  Map<String, String> labelMap = {};

  /// AIY food-classifier label (lowercase) -> food id (offline model).
  Map<String, String> aiyMap = {};
  int version = 0;

  Future<File> _syncedFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'foods.json'));
  }

  Future<void> load() async {
    _parse(await rootBundle.loadString('assets/data/foods.json'));
    final synced = await _syncedFile();
    if (await synced.exists()) {
      try {
        _parse(await synced.readAsString()); // only if newer
      } catch (_) {}
    }
    final lm = await rootBundle.loadString('assets/data/labels_map.json');
    labelMap = (jsonDecode(lm) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k.toLowerCase(), v as String));
    try {
      final am = await rootBundle.loadString('assets/data/aiy_map.json');
      aiyMap = (jsonDecode(am) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String));
    } catch (_) {}
  }

  void _parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final v = (j['version'] as num?)?.toInt() ?? 0;
    final list = (j['foods'] as List)
        .map((e) => Food.fromJson(e as Map<String, dynamic>))
        .toList();
    // an older synced copy must not replace a bigger bundled table
    if (foods.isNotEmpty && v < version) return;
    version = v;
    foods = list;
    _byId = {for (final f in foods) f.id: f};
  }

  Map<String, Food> _byId = {};

  Future<void> saveSynced(String raw) async {
    _parse(raw); // throws if invalid
    final f = await _syncedFile();
    await f.writeAsString(raw);
  }

  Food? byId(String id) => _byId[id];

  /// Grams for [n] of [unit] of food [f] ('g', 'portion' or a household unit).
  static double unitGrams(Food f, String unit) {
    if (unit == 'g') return 1;
    if (unit == 'portion') return f.portion;
    final u = f.units[unit];
    if (u != null) return u;
    return defaultUnits(f)[unit] ?? f.portion;
  }

  /// Household units that make sense for a food, with grams.
  static Map<String, double> defaultUnits(Food f) {
    final m = <String, double>{};
    switch (f.cat) {
      case 'soup':
        m['ladle'] = 200;
        m['bowl'] = 300;
      case 'legume':
      case 'vegetable':
        m['ladle'] = 150;
        m['tbsp'] = 20;
      case 'grain':
        m['tbsp'] = 20;
        m['ladle'] = 120;
      case 'drink':
        m['glass'] = 200;
        m['teacup'] = 100;
      case 'dairy':
        m['tbsp'] = 20;
      case 'misc':
        m['tbsp'] = 15;
        m['tsp'] = 5;
    }
    m.addAll(f.units);
    return m;
  }

  /// Map an ML Kit label (English) to a food.
  Food? fromLabel(String label) {
    final l = label.toLowerCase().trim();
    final id = labelMap[l];
    if (id != null) return byId(id);
    // fuzzy: label contained in any english name or vice versa
    for (final f in foods) {
      final n = f.en.toLowerCase();
      if (n == l) return f;
    }
    for (final f in foods) {
      final n = f.en.toLowerCase();
      if (n.contains(l) || l.contains(n)) return f;
    }
    return null;
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Best single match for a free-text food name typed by the user.
  Food? bestMatch(String q) {
    final m = scoredMatch(q);
    return m != null && m.$2 >= 15 ? m.$1 : null;
  }

  /// Best match with its score (100 = exact name).
  (Food, int)? scoredMatch(String q) {
    final s = _norm(q);
    if (s.length < 2) return null;
    Food? best;
    var bestScore = 0;
    for (final f in foods) {
      for (final n in [f.tr, f.en, f.ar]) {
        final x = _norm(n);
        if (x.isEmpty) continue;
        int score = 0;
        if (x == s) {
          score = 100;
        } else if (x.startsWith(s) || s.startsWith(x)) {
          score = 70 - (x.length - s.length).abs();
        } else if (x.contains(s) || s.contains(x)) {
          score = 50 - (x.length - s.length).abs();
        } else {
          // word overlap
          final a = s.split(' ').where((w) => w.length > 2).toSet();
          final b = x.split(' ').where((w) => w.length > 2).toSet();
          final common = a.intersection(b).length;
          if (common > 0) score = 20 * common - (b.length - common);
        }
        if (score > bestScore) {
          bestScore = score;
          best = f;
        }
      }
    }
    return best == null ? null : (best, bestScore);
  }

  List<Food> search(String q, String lang) {
    final s = q.toLowerCase().trim();
    if (s.isEmpty) return foods;
    return foods
        .where((f) =>
            f.name(lang).toLowerCase().contains(s) ||
            f.en.toLowerCase().contains(s) ||
            f.tr.toLowerCase().contains(s) ||
            f.ar.contains(s))
        .toList();
  }
}
