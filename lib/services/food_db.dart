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
