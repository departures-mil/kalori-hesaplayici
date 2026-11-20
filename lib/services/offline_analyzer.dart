import 'dart:io';

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../data/models.dart';
import 'food_db.dart';
import 'plate_hint.dart';

/// On-device analysis with ML Kit image labeling + local nutrition table.
class OfflineAnalyzer {
  static Future<AnalysisResult> analyze(File file, String lang,
      {String? hint}) async {
    // 1) Foods the user typed: these are trusted and come first.
    final db0 = FoodDb.instance;
    final hinted = <FoodItem>[];
    final hintedIds = <String>{};
    for (final h in PlateHint.parse(hint)) {
      final f = db0.bestMatch(h.name);
      if (f == null) continue;
      if (hintedIds.contains(f.id)) continue;
      hintedIds.add(f.id);
      final grams = h.grams ?? (h.count != null ? h.count! * f.portion : null);
      hinted.add(FoodItem.fromFood(f, lang, grams: grams)..confidence = 0.95);
    }
    final labeler =
        ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.35));
    try {
      final input = InputImage.fromFile(file);
      final labels = await labeler.processImage(input);
      labels.sort((a, b) => b.confidence.compareTo(a.confidence));

      final db = FoodDb.instance;
      final items = <FoodItem>[...hinted];
      final seen = <String>{...hintedIds};
      var foodish = false;
      for (final l in labels) {
        final txt = l.label.toLowerCase();
        if (const ['food', 'dish', 'cuisine', 'meal', 'snack', 'dessert',
                'fruit', 'vegetable', 'drink', 'breakfast', 'lunch', 'dinner']
            .contains(txt)) {
          foodish = true;
        }
        final f = db.fromLabel(l.label);
        if (f == null || seen.contains(f.id)) continue;
        // with a user list, only add very confident extra items
        if (hinted.isNotEmpty && l.confidence < 0.7) continue;
        // skip very generic mappings when we already have specific ones
        final generic = const [
          'food', 'dish', 'cuisine', 'lunch', 'dinner', 'breakfast', 'brunch',
          'snack', 'sweet', 'dessert', 'fruit', 'vegetable', 'drink', 'meat',
          'baked goods', 'confectionery', 'junk food', 'fast food'
        ].contains(txt);
        if (generic && items.isNotEmpty) continue;
        seen.add(f.id);
        items.add(FoodItem.fromFood(f, lang)..confidence = l.confidence);
        if (items.length >= hinted.length + 4) break;
      }
      // If only a generic hit, keep just one.
      if (items.isEmpty && foodish) {
        final f = db.byId('rice_cooked');
        if (f != null) items.add(FoodItem.fromFood(f, lang)..confidence = 0.3);
      }
      return AnalysisResult(
        items: items,
        source: AnalysisSource.offline,
        modelUsed: 'mlkit',
      );
    } finally {
      labeler.close();
    }
  }
}
