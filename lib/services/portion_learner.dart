import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';

/// Learns from the user's corrections: if someone keeps changing "rice
/// 200 g" to 140 g, the next estimate for rice starts lower. Stored only on
/// this phone (per food and an overall factor).
class PortionLearner {
  PortionLearner._();
  static final PortionLearner instance = PortionLearner._();

  static const _k = 'portionLearn_v1';
  static const _kOn = 'portionLearnOn';
  late SharedPreferences _p;
  Map<String, List<double>> _m = {}; // key -> [ratio, count]

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    try {
      final raw = _p.getString(_k);
      if (raw != null) {
        _m = (jsonDecode(raw) as Map<String, dynamic>).map((k, v) =>
            MapEntry(k, (v as List).map((e) => (e as num).toDouble()).toList()));
      }
    } catch (_) {
      _m = {};
    }
  }

  bool get enabled => _p.getBool(_kOn) ?? true;
  set enabled(bool v) => _p.setBool(_kOn, v);

  int get learnedCount => _m.keys.where((k) => k != '_all').length;

  Future<void> reset() async {
    _m = {};
    await _p.remove(_k);
  }

  static String keyOf(FoodItem it) {
    final id = it.foodId;
    if (id != null && id.isNotEmpty) return id;
    return (it.nameEn ?? it.name)
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Adjusts the estimated grams of fresh analysis items.
  /// With [userListed], items the user typed (confidence >= 0.9) keep the
  /// amount the user gave.
  void apply(List<FoodItem> items, {bool userListed = false}) {
    for (final it in items) {
      it.predGrams ??= it.grams;
      if (!enabled) continue;
      if (userListed && it.confidence >= 0.9) continue;
      final own = _m[keyOf(it)];
      final all = _m['_all'];
      double? r;
      if (own != null && own[1] >= 1) {
        r = own[0];
      } else if (all != null && all[1] >= 3) {
        r = 1 + (all[0] - 1) * 0.5; // overall habit, at half strength
      }
      if (r == null || (r - 1).abs() < 0.05) continue;
      final k = r.clamp(0.5, 2.0).toDouble();
      it.grams = (it.grams * k).roundToDouble().clamp(5.0, 1500.0).toDouble();
      it.learned = true;
    }
  }

  /// Called when an analysis is saved: compares the user's final grams with
  /// the analysis' own estimate.
  Future<void> record(List<FoodItem> items) async {
    if (!enabled) return;
    var changed = false;
    for (final it in items) {
      final pred = it.predGrams;
      if (pred == null || pred <= 0) continue;
      final target = (it.grams / pred).clamp(0.4, 2.5).toDouble();
      for (final key in [keyOf(it), '_all']) {
        final cur = _m[key];
        if (cur == null) {
          // first correction counts half, so one odd meal does not dominate
          _m[key] = [1 + (target - 1) * 0.5, 1];
        } else {
          final n = cur[1];
          final a = n < 3 ? 0.4 : 0.25;
          _m[key] = [cur[0] + (target - cur[0]) * a, n + 1];
        }
      }
      changed = true;
    }
    if (changed) await _p.setString(_k, jsonEncode(_m));
  }
}
