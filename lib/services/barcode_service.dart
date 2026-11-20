import 'dart:convert';
import 'dart:io';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:http/http.dart' as http;

import '../data/db.dart';
import '../data/models.dart';

class BarcodeService {
  static Future<String?> readBarcode(File file) async {
    final scanner = BarcodeScanner(formats: [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upca,
      BarcodeFormat.upce,
      BarcodeFormat.code128,
    ]);
    try {
      final codes = await scanner.processImage(InputImage.fromFile(file));
      if (codes.isEmpty) return null;
      return codes.first.rawValue;
    } finally {
      scanner.close();
    }
  }

  /// Looks up the product in the local cache first, then Open Food Facts.
  static Future<AnalysisResult?> lookup(String barcode, String lang) async {
    final db = AppDb.instance;
    var j = await db.cachedProduct(barcode);
    if (j == null) {
      try {
        final res = await http
            .get(Uri.parse(
                'https://world.openfoodfacts.org/api/v2/product/$barcode.json?fields=product_name,product_name_tr,product_name_ar,product_name_en,nutriments,serving_quantity,quantity'))
            .timeout(const Duration(seconds: 20));
        if (res.statusCode == 200) {
          final m = jsonDecode(res.body) as Map<String, dynamic>;
          if (m['status'] == 1 && m['product'] != null) {
            j = m['product'] as Map<String, dynamic>;
            await db.cacheProduct(barcode, j);
          }
        }
      } catch (_) {}
    }
    if (j == null) return null;
    final n = (j['nutriments'] as Map?) ?? {};
    double v(String k) => (n[k] as num?)?.toDouble() ?? 0;
    var kcal = v('energy-kcal_100g');
    if (kcal == 0) kcal = v('energy_100g') / 4.184;
    final name = (j['product_name_$lang'] as String?)?.trim().isNotEmpty == true
        ? j['product_name_$lang'] as String
        : (j['product_name'] as String? ?? barcode);
    final serving = (j['serving_quantity'] as num?)?.toDouble();
    final item = FoodItem(
      name: name,
      grams: (serving != null && serving > 0) ? serving : 100,
      kcalPer100: kcal,
      proteinPer100: v('proteins_100g'),
      carbsPer100: v('carbohydrates_100g'),
      fatPer100: v('fat_100g'),
      confidence: 1,
    );
    return AnalysisResult(
        items: [item], source: AnalysisSource.barcode, modelUsed: 'off');
  }
}
