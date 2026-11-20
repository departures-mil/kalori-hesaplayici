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
  int version = 0;

  Future<File> _syncedFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'foods.json'));
  }

  Future<void> load() async {
    String raw;
    final synced = await _syncedFile();
    if (await synced.exists()) {
      raw = await synced.readAsString();
    } else {
      raw = await rootBundle.loadString('assets/data/foods.json');
    }
    _parse(raw);
    final lm = await rootBundle.loadString('assets/data/labels_map.json');
    labelMap = (jsonDecode(lm) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k.toLowerCase(), v as String));
  }

  void _parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    version = (j['version'] as num?)?.toInt() ?? 0;
    foods = (j['foods'] as List)
        .map((e) => Food.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveSynced(String raw) async {
    _parse(raw); // throws if invalid
    final f = await _syncedFile();
    await f.writeAsString(raw);
  }

  Food? byId(String id) {
    for (final f in foods) {
      if (f.id == id) return f;
    }
    return null;
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
    return bestScore >= 15 ? best : null;
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
