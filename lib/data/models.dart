class Food {
  final String id;
  final String en, tr, ar;
  final double kcal, protein, carbs, fat; // per 100 g
  final double portion; // default portion in grams
  final String cat;

  const Food({
    required this.id,
    required this.en,
    required this.tr,
    required this.ar,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.portion,
    required this.cat,
  });

  factory Food.fromJson(Map<String, dynamic> j) => Food(
        id: j['id'] as String,
        en: j['en'] as String,
        tr: j['tr'] as String,
        ar: j['ar'] as String,
        kcal: (j['kcal'] as num).toDouble(),
        protein: (j['p'] as num).toDouble(),
        carbs: (j['c'] as num).toDouble(),
        fat: (j['f'] as num).toDouble(),
        portion: (j['portion'] as num).toDouble(),
        cat: j['cat'] as String? ?? 'misc',
      );

  String name(String lang) => switch (lang) {
        'tr' => tr,
        'ar' => ar,
        _ => en,
      };
}

enum AnalysisSource { ai, offline, barcode, manual }

/// One detected food item in an analysis (or one diary line).
class FoodItem {
  String name;
  double grams;
  double kcalPer100;
  double proteinPer100;
  double carbsPer100;
  double fatPer100;
  double confidence; // 0..1
  String? foodId;

  FoodItem({
    required this.name,
    required this.grams,
    required this.kcalPer100,
    this.proteinPer100 = 0,
    this.carbsPer100 = 0,
    this.fatPer100 = 0,
    this.confidence = 1,
    this.foodId,
  });

  double get kcal => kcalPer100 * grams / 100;
  double get protein => proteinPer100 * grams / 100;
  double get carbs => carbsPer100 * grams / 100;
  double get fat => fatPer100 * grams / 100;

  factory FoodItem.fromFood(Food f, String lang, {double? grams}) => FoodItem(
        name: f.name(lang),
        grams: grams ?? f.portion,
        kcalPer100: f.kcal,
        proteinPer100: f.protein,
        carbsPer100: f.carbs,
        fatPer100: f.fat,
        foodId: f.id,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'grams': grams,
        'kcal100': kcalPer100,
        'p100': proteinPer100,
        'c100': carbsPer100,
        'f100': fatPer100,
        'conf': confidence,
        'foodId': foodId,
      };

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
        name: j['name'] as String,
        grams: (j['grams'] as num).toDouble(),
        kcalPer100: (j['kcal100'] as num).toDouble(),
        proteinPer100: (j['p100'] as num? ?? 0).toDouble(),
        carbsPer100: (j['c100'] as num? ?? 0).toDouble(),
        fatPer100: (j['f100'] as num? ?? 0).toDouble(),
        confidence: (j['conf'] as num? ?? 1).toDouble(),
        foodId: j['foodId'] as String?,
      );
}

class AnalysisResult {
  final List<FoodItem> items;
  final AnalysisSource source;
  final String? note;
  final String? imagePath;
  final String? modelUsed;

  /// What the user typed about the plate contents (helps the analysis).
  final String? hint;

  /// Localization key + raw detail when online AI failed.
  final String? errorKey;
  final String? errorDetail;

  AnalysisResult({
    required this.items,
    required this.source,
    this.note,
    this.imagePath,
    this.modelUsed,
    this.hint,
    this.errorKey,
    this.errorDetail,
  });

  double get totalKcal => items.fold(0, (s, i) => s + i.kcal);
  double get totalProtein => items.fold(0, (s, i) => s + i.protein);
  double get totalCarbs => items.fold(0, (s, i) => s + i.carbs);
  double get totalFat => items.fold(0, (s, i) => s + i.fat);
}

enum MealType { breakfast, lunch, dinner, snack }

class DiaryEntry {
  final int? id;
  final DateTime time;
  final MealType meal;
  final List<FoodItem> items;
  final AnalysisSource source;
  final String? imagePath;
  final String? note;

  DiaryEntry({
    this.id,
    required this.time,
    required this.meal,
    required this.items,
    required this.source,
    this.imagePath,
    this.note,
  });

  double get kcal => items.fold(0, (s, i) => s + i.kcal);
  double get protein => items.fold(0, (s, i) => s + i.protein);
  double get carbs => items.fold(0, (s, i) => s + i.carbs);
  double get fat => items.fold(0, (s, i) => s + i.fat);
  String get title => items.map((e) => e.name).join(', ');
}

class DaySummary {
  final DateTime day;
  final double kcal;
  final int entries;
  DaySummary(this.day, this.kcal, this.entries);
}
