import 'dart:io';

import '../data/models.dart';
import 'food_db.dart';
import 'nutrition_db.dart';
import 'online_analyzer.dart';

/// 1.1.1 — yazarak ya da sesle öğün: "1 kase mercimek çorbası, 2 dilim ekmek".
/// Önce kullanıcının kendi yapay zekâ anahtarıyla (internet varsa), olmazsa
/// cihazda: cümle parçalara ayrılır, miktar + ölçü + yiyecek adı çözülür,
/// kalori yerel tablodan / USDA'dan gelir. Üç dil: tr / en / ar.
class TextEntry {
  /// Çevrim içi (anahtar + internet) → olmazsa çevrimdışı.
  static Future<AnalysisResult> parse(String text, String lang, {bool online = true}) async {
    final t = text.trim();
    if (t.isEmpty) return AnalysisResult(items: [], source: AnalysisSource.manual);
    if (online && await _hasNet()) {
      try {
        final r = await OnlineAnalyzer.parseText(t, lang);
        if (r != null && r.items.isNotEmpty) {
          for (final i in r.items) {
            i.confirmed = true; // kullanıcının kendi söylediği
          }
          return AnalysisResult(
              items: r.items, source: AnalysisSource.manual, modelUsed: r.modelUsed, hint: t);
        }
      } catch (_) {}
    }
    await NutritionDb.instance.load();
    return AnalysisResult(items: parseOffline(t, lang), source: AnalysisSource.manual, hint: t);
  }

  static Future<bool> _hasNet() async {
    try {
      final r = await InternetAddress.lookup('generativelanguage.googleapis.com')
          .timeout(const Duration(seconds: 3));
      return r.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------- çevrimdışı

  static const _numWords = <String, double>{
    // tr
    'bir': 1, 'iki': 2, 'üç': 3, 'uc': 3, 'üc': 3, 'dört': 4, 'dort': 4, 'beş': 5, 'bes': 5,
    'altı': 6, 'alti': 6, 'yedi': 7, 'sekiz': 8, 'dokuz': 9, 'on': 10,
    'yarım': 0.5, 'yarim': 0.5, 'çeyrek': 0.25, 'ceyrek': 0.25,
    // en
    'a': 1, 'an': 1, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
    'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'half': 0.5, 'quarter': 0.25,
    'couple': 2,
    // ar
    'واحد': 1, 'واحدة': 1, 'اثنين': 2, 'اثنان': 2, 'اثنتين': 2, 'ثلاث': 3, 'ثلاثة': 3,
    'أربع': 4, 'اربع': 4, 'أربعة': 4, 'خمس': 5, 'خمسة': 5, 'ست': 6, 'ستة': 6,
    'سبع': 7, 'سبعة': 7, 'ثمان': 8, 'ثمانية': 8, 'تسع': 9, 'عشر': 10, 'عشرة': 10,
    'نصف': 0.5, 'ربع': 0.25,
  };

  /// Ölçü kelimesi → birim anahtarı (FoodDb birimleri).
  static const _unitWords = <String, String>{
    // tr
    'gram': 'g', 'gr': 'g', 'g': 'g', 'kg': 'kg', 'kilo': 'kg', 'ml': 'ml', 'litre': 'l', 'lt': 'l',
    'kase': 'bowl', 'kâse': 'bowl', 'tas': 'bowl', 'çanak': 'bowl',
    'dilim': 'slice', 'parça': 'piece', 'parca': 'piece', 'adet': 'piece', 'tane': 'piece',
    'bardak': 'glass', 'su bardağı': 'glass', 'çay bardağı': 'teacup', 'fincan': 'teacup',
    'kupa': 'cup', 'kepçe': 'ladle', 'kepce': 'ladle', 'kaşık': 'tbsp', 'kasik': 'tbsp',
    'yemek kaşığı': 'tbsp', 'tatlı kaşığı': 'tsp', 'çay kaşığı': 'tsp',
    'porsiyon': 'portion', 'tabak': 'portion', 'avuç': 'handful', 'avuc': 'handful',
    // en
    'grams': 'g', 'kgs': 'kg', 'bowl': 'bowl', 'bowls': 'bowl', 'slice': 'slice', 'slices': 'slice',
    'piece': 'piece', 'pieces': 'piece', 'pcs': 'piece', 'glass': 'glass', 'glasses': 'glass',
    'cup': 'cup', 'cups': 'cup', 'mug': 'cup', 'ladle': 'ladle', 'ladles': 'ladle',
    'tablespoon': 'tbsp', 'tablespoons': 'tbsp', 'tbsp': 'tbsp', 'spoon': 'tbsp', 'spoons': 'tbsp',
    'teaspoon': 'tsp', 'teaspoons': 'tsp', 'tsp': 'tsp', 'portion': 'portion', 'portions': 'portion',
    'serving': 'portion', 'servings': 'portion', 'plate': 'portion', 'handful': 'handful',
    // ar
    'غرام': 'g', 'جرام': 'g', 'غ': 'g', 'كيلو': 'kg', 'مل': 'ml', 'لتر': 'l',
    'صحن': 'bowl', 'طبق': 'portion', 'وعاء': 'bowl', 'زبدية': 'bowl',
    'شريحة': 'slice', 'شرائح': 'slice', 'قطعة': 'piece', 'قطع': 'piece', 'حبة': 'piece', 'حبات': 'piece',
    'كوب': 'glass', 'أكواب': 'glass', 'كأس': 'glass', 'فنجان': 'teacup', 'استكانة': 'teacup',
    'مغرفة': 'ladle', 'ملعقة': 'tbsp', 'ملاعق': 'tbsp', 'ملعقة كبيرة': 'tbsp', 'ملعقة صغيرة': 'tsp',
    'حصة': 'portion', 'حصص': 'portion', 'حفنة': 'handful',
  };

  /// Yiyecekte bu birim tanımlı değilse genel gram karşılığı.
  static const _genericGrams = <String, double>{
    'bowl': 300, 'slice': 30, 'glass': 200, 'teacup': 100, 'cup': 240, 'ladle': 150,
    'tbsp': 15, 'tsp': 5, 'handful': 30,
  };

  static String _arabicDigits(String s) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = ar.indexOf(ch);
      b.write(i >= 0 ? '$i' : ch);
    }
    return b.toString().replaceAll('٫', '.').replaceAll('½', ' 0.5 ').replaceAll('¼', ' 0.25 ');
  }

  /// Cümleyi yiyecek parçalarına böler.
  static List<String> split(String text) {
    var t = _arabicDigits(text.toLowerCase());
    t = t.replaceAll(RegExp(r'[\n;+،؛]'), ',');
    t = t.replaceAll(RegExp(r'\s+(ve|ile|and|with|plus|ayrıca|bir de)\s+'), ',');
    t = t.replaceAll(RegExp(r'\s+و\s*(?=\d|نصف|ربع|كوب|صحن|شريحة|قطعة|حبة|ملعقة|فنجان)'), ',');
    t = t.replaceAll(RegExp(r'\s+و\s+'), ',');
    // "1,5" ondalık virgülünü koru
    t = t.replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}.${m[2]}');
    return t
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && RegExp(r'[^\d\s.]').hasMatch(e))
        .toList();
  }

  /// Bir parçadan miktar, birim ve ad.
  static ({double qty, String? unit, String name}) chunk(String c) {
    var words = c.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    double? qty;
    String? unit;
    // "150g", "200ml" bitişik
    final glued = RegExp(r'^(\d+(?:\.\d+)?)(g|gr|gram|kg|ml|lt|l|غ|مل)$');
    final out = <String>[];
    var i = 0;
    while (i < words.length) {
      final w = words[i];
      final g = glued.firstMatch(w);
      if (g != null && qty == null) {
        qty = double.parse(g[1]!);
        unit = _unitWords[g[2]!] ?? (g[2] == 'l' ? 'l' : 'g');
        i++;
        continue;
      }
      final n = double.tryParse(w);
      if (n != null && qty == null) {
        qty = n;
        i++;
        continue;
      }
      if (qty == null && _numWords.containsKey(w) && (w != 'on' || i + 1 < words.length)) {
        // "a"/"an" yalnızca başta sayı sayılır
        if ((w == 'a' || w == 'an') && i != 0) {
          out.add(w);
          i++;
          continue;
        }
        qty = _numWords[w];
        // "bir buçuk", "iki buçuk"
        if (i + 1 < words.length && (words[i + 1] == 'buçuk' || words[i + 1] == 'bucuk')) {
          qty = qty! + 0.5;
          i++;
        }
        i++;
        continue;
      }
      if (unit == null) {
        // iki kelimelik ölçüler önce: "su bardağı", "yemek kaşığı", "ملعقة صغيرة"
        if (i + 1 < words.length) {
          final two = '$w ${words[i + 1]}';
          final u2 = _unitWords[two] ?? _unitWords[_stem(two)];
          if (u2 != null) {
            unit = u2;
            i += 2;
            continue;
          }
        }
        final u = _unitWords[w] ?? _unitWords[_stem(w)];
        if (u != null && (out.isEmpty || qty != null)) {
          unit = u;
          i++;
          continue;
        }
      }
      if (w == 'of' || w == 'من') {
        i++;
        continue;
      }
      out.add(w);
      i++;
    }
    return (qty: qty ?? 1.0, unit: unit, name: out.join(' ').trim());
  }

  /// Türkçe iyelik/çoğul ekleri: "bardağı" → "bardak", "kaşığı" → "kaşık", "dilimi" → "dilim".
  static String _stem(String w) {
    var x = w;
    x = x.replaceAll(RegExp(r'ğı$'), 'k').replaceAll(RegExp(r'ği$'), 'k');
    x = x.replaceAll(RegExp(r'(lar|ler)$'), '');
    if (x.length > 4) x = x.replaceAll(RegExp(r'(ı|i|u|ü)$'), '');
    return x;
  }

  static List<FoodItem> parseOffline(String text, String lang) {
    final out = <FoodItem>[];
    for (final c in split(text)) {
      final p = chunk(c);
      if (p.name.isEmpty) continue;
      out.add(_toItem(p.qty, p.unit, p.name, lang));
    }
    return out;
  }

  static FoodItem _toItem(double qty, String? unit, String name, String lang) {
    final db = FoodDb.instance;
    final m = db.scoredMatch(name);
    if (m != null && m.$2 >= 40) {
      final f = m.$1;
      final g = _grams(qty, unit, f);
      return FoodItem.fromFood(f, lang, grams: g.roundToDouble())
        ..confirmed = true
        ..confidence = m.$2 >= 67 ? 0.9 : 0.7;
    }
    // USDA (İngilizce ad)
    final u = NutritionDb.instance.matchUsda(name);
    if (u != null) {
      final per = unit == null || unit == 'portion' || unit == 'piece'
          ? (u.householdG > 0 ? u.householdG : 100.0)
          : _plainGrams(unit) ?? 100.0;
      return FoodItem(
        name: name,
        nameEn: u.desc,
        grams: (qty * per).roundToDouble(),
        kcalPer100: u.kcal,
        proteinPer100: u.protein,
        carbsPer100: u.carbs,
        fatPer100: u.fat,
        dataSource: 'usda',
        confidence: 0.6,
        confirmed: true,
      );
    }
    // bulunamadı: kullanıcı onay ekranında düzeltir (kalori 0, soru işaretli)
    final per = unit == null ? 100.0 : (_plainGrams(unit) ?? _genericGrams[unit] ?? 100.0);
    return FoodItem(
      name: name,
      grams: (qty * per).roundToDouble(),
      kcalPer100: 0,
      confidence: 0.2,
      dataSource: 'user',
    );
  }

  static double? _plainGrams(String unit) => switch (unit) {
        'g' => 1,
        'kg' => 1000,
        'ml' => 1,
        'l' => 1000,
        _ => null,
      };

  static double _grams(double qty, String? unit, Food f) {
    if (unit == null || unit == 'portion') return qty * f.portion;
    final plain = _plainGrams(unit);
    if (plain != null) return qty * plain;
    if (unit == 'piece') return qty * (f.units['piece'] ?? f.portion);
    final known = FoodDb.defaultUnits(f)[unit];
    if (known != null) return qty * known;
    return qty * (_genericGrams[unit] ?? f.portion);
  }
}
