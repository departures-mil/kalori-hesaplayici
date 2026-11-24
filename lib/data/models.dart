import 'dart:io';

class Food {
  final String id;
  final String en, tr, ar;
  final double kcal, protein, carbs, fat; // per 100 g
  final double portion; // default portion in grams
  final String cat;

  /// Household units for this food (unit key -> grams), e.g. {"slice": 30}.
  final Map<String, double> units;

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
    this.units = const {},
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
        units: (j['u'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
            const {},
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

  /// v1.0.11 — more realistic results
  String? nameEn; // English name from the AI (for database lookup)
  double? gramsMin; // estimated range
  double? gramsMax;
  String? cook; // raw / boiled / grilled / baked / stewed / fried
  String? cookBase; // cooking style the nutrition values already include
  String oil; // none / normal / high (relative to the values)
  double? predGrams; // the analysis' own estimate, before learning/user edit
  String? dataSource; // db / usda / ai / user
  String? question; // what the analysis is unsure about (user's language)
  bool learned; // grams adjusted from the user's past corrections
  bool confirmed; // user ticked "correct"

  FoodItem({
    required this.name,
    required this.grams,
    required this.kcalPer100,
    this.proteinPer100 = 0,
    this.carbsPer100 = 0,
    this.fatPer100 = 0,
    this.confidence = 1,
    this.foodId,
    this.nameEn,
    this.gramsMin,
    this.gramsMax,
    this.cook,
    this.cookBase,
    this.oil = 'normal',
    this.predGrams,
    this.dataSource,
    this.question,
    this.learned = false,
    this.confirmed = false,
  });

  /// Grams of oil per 100 g of food each cooking style typically adds.
  static const cookOil = {
    'raw': 0.0,
    'boiled': 0.0,
    'grilled': 1.0,
    'baked': 2.5,
    'stewed': 3.0,
    'fried': 9.0,
  };
  static const oilLevel = {'none': -2.5, 'normal': 0.0, 'high': 4.0};

  /// Cooking style a stored value most likely already includes.
  static String guessCook(String text) {
    final t = text.toLowerCase();
    bool has(List<String> w) => w.any(t.contains);
    if (has(['fried', 'kızar', 'kizar', 'tava', 'مقلي', 'çıtır', 'crispy', 'nugget', 'fries', 'chips', 'cips'])) {
      return 'fried';
    }
    if (has(['grill', 'ızgara', 'izgara', 'kebab', 'kebap', 'مشوي', 'şiş'])) {
      return 'grilled';
    }
    if (has(['baked', 'roast', 'fırın', 'firin', 'oven', 'بالفرن'])) return 'baked';
    if (has(['boiled', 'haşla', 'hasla', 'steamed', 'buhar', 'مسلوق'])) {
      return 'boiled';
    }
    if (has(['raw', 'çiğ', 'salad', 'salata', 'سلطة', 'fruit'])) return 'raw';
    return 'stewed';
  }

  /// Extra (or less) oil per 100 g compared with the stored values: only the
  /// user's changes count, the values already include the detected style.
  double get oilPer100 {
    var d = 0.0;
    if (cook != null && cookBase != null && cook != cookBase) {
      d += (cookOil[cook] ?? 0) - (cookOil[cookBase] ?? 0);
    }
    d += oilLevel[oil] ?? 0;
    // cannot remove more fat than the food has
    final minD = -fatPer100 * 0.7;
    return d < minD ? minD : d;
  }

  double get effKcal100 => kcalPer100 + oilPer100 * 9;
  double get effFat100 => fatPer100 + oilPer100;

  double get kcal => effKcal100 * grams / 100;
  double get protein => proteinPer100 * grams / 100;
  double get carbs => carbsPer100 * grams / 100;
  double get fat => effFat100 * grams / 100;

  /// Low / high estimate in grams. Falls back to a spread from confidence.
  double get minGrams {
    if (confirmed) return grams;
    final g = gramsMin;
    if (g != null && g > 0 && g <= grams) return g * _scale;
    return grams * (1 - _spread);
  }

  double get maxGrams {
    if (confirmed) return grams;
    final g = gramsMax;
    if (g != null && g >= grams) return g * _scale;
    return grams * (1 + _spread);
  }

  // keep the AI's range proportional when the user moves the slider
  double get _scale {
    final p = predGrams;
    if (p == null || p <= 0 || gramsMin == null) return 1;
    return grams / p;
  }

  double get _spread => 0.08 + (1 - confidence.clamp(0.0, 1.0).toDouble()) * 0.35;
  double get kcalMin => effKcal100 * minGrams / 100;
  double get kcalMax => effKcal100 * maxGrams / 100;

  factory FoodItem.fromFood(Food f, String lang, {double? grams}) => FoodItem(
        name: f.name(lang),
        grams: grams ?? f.portion,
        kcalPer100: f.kcal,
        proteinPer100: f.protein,
        carbsPer100: f.carbs,
        fatPer100: f.fat,
        foodId: f.id,
        nameEn: f.en,
        dataSource: 'db',
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
        if (nameEn != null) 'en': nameEn,
        if (gramsMin != null) 'gmin': gramsMin,
        if (gramsMax != null) 'gmax': gramsMax,
        if (cook != null) 'cook': cook,
        if (cookBase != null) 'cookB': cookBase,
        if (oil != 'normal') 'oil': oil,
        if (predGrams != null) 'pred': predGrams,
        if (dataSource != null) 'src': dataSource,
        if (question != null) 'q': question,
        if (learned) 'learned': true,
        if (confirmed) 'ok': true,
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
        nameEn: j['en'] as String?,
        gramsMin: (j['gmin'] as num?)?.toDouble(),
        gramsMax: (j['gmax'] as num?)?.toDouble(),
        cook: j['cook'] as String?,
        cookBase: j['cookB'] as String?,
        oil: j['oil'] as String? ?? 'normal',
        predGrams: (j['pred'] as num?)?.toDouble(),
        dataSource: j['src'] as String?,
        question: j['q'] as String?,
        learned: j['learned'] == true,
        confirmed: j['ok'] == true,
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

/// What the user adds before the analysis: a list of foods, a size
/// reference and an optional side photo (helps estimate height / volume).
class PlateInput {
  final String hint;
  final String ref; // none / fork / spoon / card / plate
  final File? side;
  const PlateInput({this.hint = '', this.ref = 'none', this.side});
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
