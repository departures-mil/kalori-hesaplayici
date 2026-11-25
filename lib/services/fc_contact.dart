import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_info.dart';

/// Ortak çekirdek FC.contact'ın Dart karşılığı — tek admin gelen kutusu (SPEC.md):
/// Firestore `comm-calc-103111111/mesajlar` (yalnız ekleme), tüm alanlar stringValue:
/// tur, uygulama, surum, platform, dil, mesaj, iletisim (isteğe bağlı), zaman (ISO), cihaz.
/// Gönderilemeyen mesaj yerel kuyruğa alınır ve sonra yeniden denenir.
/// Programda hiçbir kişisel e-posta adresi bulunmaz (yedek e-posta yolu yok).
class FcContact {
  static const _inbox =
      'https://firestore.googleapis.com/v1/projects/comm-calc-103111111/databases/(default)/documents/mesajlar?key=AIzaSyB12RFS6ENPpmnnPsETfjedNH-3hmNWQvA';
  static const _qKey = 'fc.contact.queue';
  static const _maxQ = 30;

  /// Uygulama dili (main.dart bağlar).
  static String Function() lang = () => 'tr';

  /// Testler için değiştirilebilir.
  static http.Client Function() client = http.Client.new;

  /// Rastgele, anonim cihaz kimliği (18 hex).
  static Future<String> deviceId() async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString('fc.device') ?? '';
    if (id.isEmpty) {
      final r = Random.secure();
      id = List.generate(9, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await p.setString('fc.device', id);
    }
    return id;
  }

  static String platform() => 'flutter/${Platform.isAndroid ? 'android' : Platform.operatingSystem}';

  /// SPEC alanları.
  static Future<Map<String, String>> fields(
      {required String tur, required String mesaj, String? iletisim, DateTime? now}) async {
    final f = <String, String>{
      'tur': tur,
      'uygulama': kAppId,
      'surum': kAppVersion,
      'platform': platform(),
      'dil': lang(),
      'mesaj': mesaj.length > 5000 ? mesaj.substring(0, 5000) : mesaj,
      'zaman': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'cihaz': await deviceId(),
    };
    final c = (iletisim ?? '').trim();
    if (c.isNotEmpty) f['iletisim'] = c.length > 160 ? c.substring(0, 160) : c;
    return f;
  }

  static Map<String, dynamic> firestoreBody(Map<String, String> f) => {
        'fields': {for (final e in f.entries) e.key: {'stringValue': e.value}}
      };

  static Future<bool> _inboxPost(Map<String, String> f) async {
    final c = client();
    try {
      final r = await c
          .post(Uri.parse(_inbox),
              headers: {'Content-Type': 'application/json'}, body: jsonEncode(firestoreBody(f)))
          .timeout(const Duration(seconds: 30));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      c.close();
    }
  }

  /// Yedek e-posta yolu kaldırıldı: programda hiçbir kişisel adres bulunmaz; mesaj kuyrukta bekler.
  static Future<bool> _mail(Map<String, String> f) async => false;

  static Future<bool> _deliver(Map<String, dynamic> item) async {
    final f = Map<String, String>.from(item['f'] as Map);
    if (await _inboxPost(f)) return true;
    return item['mail'] == true ? _mail(f) : false;
  }

  static Future<List<Map<String, dynamic>>> queue() async {
    final p = await SharedPreferences.getInstance();
    try {
      final l = jsonDecode(p.getString(_qKey) ?? '[]');
      if (l is List) return [for (final x in l) Map<String, dynamic>.from(x as Map)];
    } catch (_) {}
    return [];
  }

  static Future<void> _setQueue(List<Map<String, dynamic>> q) async {
    final p = await SharedPreferences.getInstance();
    final keep = q.length > _maxQ ? q.sublist(q.length - _maxQ) : q;
    await p.setString(_qKey, jsonEncode(keep));
  }

  /// 'sent' ya da 'queued'.
  static Future<String> post({required String tur, required String mesaj, String? iletisim, bool mail = false}) async {
    final item = {'f': await fields(tur: tur, mesaj: mesaj, iletisim: iletisim), 'mail': mail};
    if (await _deliver(item)) {
      flush();
      return 'sent';
    }
    final q = await queue();
    q.add(item);
    await _setQueue(q);
    return 'queued';
  }

  /// Kullanıcı mesajı (öneri / hata): gelen kutusu, olmazsa e-posta yedeği, olmazsa kuyruk.
  static Future<String> send({required String tur, required String mesaj, String? iletisim}) =>
      post(tur: tur == 'hata' ? 'hata' : 'oneri', mesaj: mesaj, iletisim: iletisim, mail: true);

  static bool _flushing = false;

  /// Kuyruktakileri sırayla yeniden dener (açılışta ve her başarılı gönderimden sonra).
  static Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      while (true) {
        final q = await queue();
        if (q.isEmpty) break;
        if (!await _deliver(q.first)) break;
        final rest = await queue();
        if (rest.isNotEmpty) rest.removeAt(0);
        await _setQueue(rest);
      }
    } finally {
      _flushing = false;
    }
  }
}
