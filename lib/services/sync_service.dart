import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../data/settings.dart';
import 'food_db.dart';

/// "Eşitle": pulls the latest nutrition table from the GitHub repo so the
/// offline database improves without a full app update.
class SyncService {
  static Future<bool> sync() async {
    final uri = Uri.parse(
        'https://raw.githubusercontent.com/$kGithubOwner/$kGithubRepo/main/assets/data/foods.json');
    final res = await http.get(uri, headers: {
      'User-Agent': 'kalori-hesaplayici'
    }).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw HttpException('sync ${res.statusCode}');
    final raw = utf8.decode(res.bodyBytes);
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final v = (j['version'] as num?)?.toInt() ?? 0;
    final db = FoodDb.instance;
    if (v > db.version) {
      await db.saveSynced(raw);
      Settings.instance.foodsVersion = v;
      return true;
    }
    return false;
  }
}
