import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Ayarlar > Kullanım Limitleri: kullanıcının KENDİ yapay zekâ anahtarlarıyla
/// bugün yaptığı istek ve token sayısı. Gün, Gemini ücretsiz katmanı gibi
/// Pasifik saatiyle gece yarısı sıfırlanır.
class Usage {
  static const _k = 'usage_v1';

  /// Pasifik saati (ABD yaz saati kuralıyla) — saat dilimi paketi gerekmez.
  static DateTime _pacificNow() {
    final u = DateTime.now().toUtc();
    final y = u.year;
    // Mart'ın 2. pazarı 10:00 UTC ile Kasım'ın 1. pazarı 09:00 UTC arası PDT (-7), diğer zaman PST (-8)
    var mar = DateTime.utc(y, 3, 8, 10);
    mar = mar.add(Duration(days: (7 - mar.weekday) % 7));
    var nov = DateTime.utc(y, 11, 1, 9);
    nov = nov.add(Duration(days: (7 - nov.weekday) % 7));
    final dst = !u.isBefore(mar) && u.isBefore(nov);
    return u.add(Duration(hours: dst ? -7 : -8));
  }

  static String today() {
    final p = _pacificNow();
    return '${p.year}-${p.month.toString().padLeft(2, '0')}-${p.day.toString().padLeft(2, '0')}';
  }

  /// Sınırların sıfırlanmasına kalan süre.
  static Duration untilReset() {
    final p = _pacificNow();
    final passed = Duration(hours: p.hour, minutes: p.minute, seconds: p.second);
    return const Duration(days: 1) - passed;
  }

  static Future<Map<String, dynamic>> load() async {
    final sp = await SharedPreferences.getInstance();
    Map<String, dynamic> v = {};
    try {
      v = jsonDecode(sp.getString(_k) ?? '{}') as Map<String, dynamic>;
    } catch (_) {}
    final t = today();
    if (v['gun'] != t) {
      v = {'gun': t, 'istek': 0, 'token': 0, 'doldu': false, 'dun': v['gun'] == null ? null : {'istek': v['istek'] ?? 0, 'token': v['token'] ?? 0}};
      await sp.setString(_k, jsonEncode(v));
    }
    return v;
  }

  /// Her yapay zekâ isteğinden sonra çağrılır; hata fırlatmaz.
  static Future<void> record(int status, String body) async {
    try {
      final v = await load();
      v['istek'] = (v['istek'] as int? ?? 0) + 1;
      final b = body.toLowerCase();
      if (status == 429 || b.contains('resource_exhausted') || b.contains('insufficient_quota') || b.contains('rate_limit')) {
        v['doldu'] = true;
      } else if (status == 200) {
        var tok = 0;
        try {
          final j = jsonDecode(body);
          if (j is Map) {
            final um = j['usageMetadata'];
            final us = j['usage'];
            if (um is Map) {
              tok = (um['totalTokenCount'] as num?)?.toInt() ?? 0;
            } else if (us is Map) {
              tok = (us['total_tokens'] as num?)?.toInt() ??
                  (((us['input_tokens'] as num?)?.toInt() ?? 0) + ((us['output_tokens'] as num?)?.toInt() ?? 0));
            }
          }
        } catch (_) {}
        v['token'] = (v['token'] as int? ?? 0) + tok;
      }
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_k, jsonEncode(v));
    } catch (_) {}
  }
}
