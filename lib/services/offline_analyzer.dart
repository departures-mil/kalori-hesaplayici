import 'dart:io';

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../data/models.dart';
import 'food_db.dart';

/// On-device analysis with ML Kit image labeling + local nutrition table.
class OfflineAnalyzer {
  static Future<AnalysisResult> analyze(File file, String lang) async {
    final labeler =
        ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.35));
    try {
      final input = InputImage.fromFile(file);
      final labels = await labeler.processImage(input);
      labels.sort((a, b) => b.confidence.compareTo(a.confidence));

      final db = FoodDb.instance;
      final items = <FoodItem>[];
      final seen = <String>{};
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
        // skip very generic mappings when we already have specific ones
        final generic = const [
          'food', 'dish', 'cuisine', 'lunch', 'dinner', 'breakfast', 'brunch',
          'snack', 'sweet', 'dessert', 'fruit', 'vegetable', 'drink', 'meat',
          'baked goods', 'confectionery', 'junk food', 'fast food'
        ].contains(txt);
        if (generic && items.isNotEmpty) continue;
        seen.add(f.id);
        items.add(FoodItem.fromFood(f, lang)..confidence = l.confidence);
        if (items.length >= 4) break;
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
