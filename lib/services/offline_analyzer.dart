import 'dart:io';

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../data/models.dart';
import 'food_db.dart';
import 'food_model.dart';
import 'plate_hint.dart';

/// On-device analysis:
///  1) foods the user typed,
///  2) the food-specific AIY model (2,023 dishes) when downloaded,
///  3) ML Kit's general labeler as a last resort,
/// all mapped to the local nutrition table.
class OfflineAnalyzer {
  static const _generic = [
    'food', 'dish', 'cuisine', 'lunch', 'dinner', 'breakfast', 'brunch',
    'snack', 'sweet', 'dessert', 'fruit', 'vegetable', 'drink', 'meat',
    'baked goods', 'confectionery', 'junk food', 'fast food'
  ];

  static Future<AnalysisResult> analyze(File file, String lang,
      {String? hint}) async {
    final db = FoodDb.instance;
    final items = <FoodItem>[];
    final seen = <String>{};

    // 1) Foods the user typed: trusted, first.
    for (final h in PlateHint.parse(hint)) {
      final f = db.bestMatch(h.name);
      if (f == null || seen.contains(f.id)) continue;
      seen.add(f.id);
      final grams = h.grams ??
          (h.count != null ? h.count! * FoodDb.unitGrams(f, 'piece') : null);
      items.add(FoodItem.fromFood(f, lang, grams: grams)
        ..confidence = 0.95
        ..cookBase = FoodItem.guessCook('${f.en} ${f.tr}'));
    }
    final hinted = items.length;
    final input = InputImage.fromFile(file);
    var model = 'mlkit';

    // 2) Food model.
    final mp = await FoodModel.instance.path();
    if (mp != null) {
      final labeler = ImageLabeler(
          options: LocalLabelerOptions(
              modelPath: mp, confidenceThreshold: 0.2, maxCount: 5));
      try {
        final labels = await labeler.processImage(input);
        labels.sort((a, b) => b.confidence.compareTo(a.confidence));
        var added = 0;
        for (final l in labels) {
          final name = l.label.trim();
          if (name.startsWith('__')) continue;
          final id = db.aiyMap[name.toLowerCase()];
          final f = id != null ? db.byId(id) : db.fromLabel(name);
          if (f == null || seen.contains(f.id)) continue;
          // with a user list, only add very confident extras
          if (hinted > 0 && l.confidence < 0.6) continue;
          // after the best guess, keep only clearly separate dishes
          if (added > 0 && l.confidence < 0.3) continue;
          seen.add(f.id);
          items.add(FoodItem.fromFood(f, lang)
            ..confidence = (l.confidence * 1.1).clamp(0.2, 0.9)
            ..cookBase = FoodItem.guessCook('${f.en} ${f.tr}'));
          added++;
          if (added >= 3) break;
        }
        if (added > 0) model = 'food-model';
      } catch (_) {
        // broken model file: fall back to the general labeler
      } finally {
        labeler.close();
      }
    }

    // 3) General labeler (also finds drinks, fruit, packaged snacks).
    final labeler =
        ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.35));
    try {
      final labels = await labeler.processImage(input);
      labels.sort((a, b) => b.confidence.compareTo(a.confidence));
      var foodish = false;
      final before = items.length;
      for (final l in labels) {
        final txt = l.label.toLowerCase();
        final generic = _generic.contains(txt);
        if (generic) foodish = true;
        final f = db.fromLabel(l.label);
        if (f == null || seen.contains(f.id)) continue;
        if (hinted > 0 && l.confidence < 0.7) continue;
        if (generic && items.isNotEmpty) continue;
        // the food model already named the dish: add only confident extras
        if (model == 'food-model' && l.confidence < 0.75) continue;
        seen.add(f.id);
        items.add(FoodItem.fromFood(f, lang)
          ..confidence = l.confidence * 0.8
          ..cookBase = FoodItem.guessCook('${f.en} ${f.tr}'));
        if (items.length - before >= 3) break;
      }
      if (items.isEmpty && foodish) {
        final f = db.byId('rice_cooked');
        if (f != null) {
          items.add(FoodItem.fromFood(f, lang)
            ..confidence = 0.25
            ..cookBase = 'stewed');
        }
      }
    } finally {
      labeler.close();
    }
    return AnalysisResult(
      items: items,
      source: AnalysisSource.offline,
      modelUsed: model,
    );
  }
}
