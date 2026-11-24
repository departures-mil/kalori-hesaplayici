import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_info.dart';
import 'fc_contact.dart';

/// Ortak çekirdek FC.crash'in Dart karşılığı: beklenmeyen hatalar yöneticinin
/// gelen kutusuna `tur: cokme` ile gider. Aynı hata imzası (sürüm başına) bir kez,
/// günde en çok 5 rapor. Yalnızca maskelenmiş hata metni + yığın gider; kayıt içeriği asla.
class FcCrash {
  static const maxPerDay = 5;
  static final _ignore = RegExp(
      r'SocketException|HandshakeException|ClientException|Connection (closed|refused|reset)|Failed host lookup|TimeoutException|Network is unreachable|OS Error: (Connection|Software caused)',
      caseSensitive: false);

  /// Testler için zaman ve gönderici değiştirilebilir.
  static DateTime Function() now = DateTime.now;
  static Future<String> Function(String text) sender =
      (t) => FcContact.post(tur: 'cokme', mesaj: t);

  static bool _installed = false;

  /// FlutterError.onError + PlatformDispatcher.onError bağlanır (main()'de bir kez).
  static void install() {
    if (_installed) return;
    _installed = true;
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      prev?.call(d);
      report(d.exception, d.stack, source: 'flutter');
    };
    final prevP = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (e, st) {
      report(e, st, source: 'async');
      return prevP?.call(e, st) ?? true;
    };
  }

  static String sanitize(String s, [int max = 600]) {
    s = s
        .replaceAll(RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+'), '<email>')
        .replaceAllMapped(RegExp(r'''(https?://[^\s?#'")]+)[?#][^\s'")]*'''), (m) => m[1]!)
        .replaceAllMapped(RegExp(r'([A-Za-z]:[\\/]Users[\\/])[^\\/\s]+', caseSensitive: false), (m) => '${m[1]}<user>')
        .replaceAllMapped(RegExp(r'(/(?:home|Users)/)[^/\s]+'), (m) => '${m[1]}<user>')
        .replaceAllMapped(RegExp(r'(/storage/emulated/\d+/)\S*'), (m) => '${m[1]}<path>')
        .replaceAllMapped(RegExp(r'(/data/(?:user/\d+|data)/[\w.]+/)\S*'), (m) => '${m[1]}<path>')
        .replaceAll(RegExp(r'\d{6,}'), '<n>')
        .replaceAllMapped(RegExp(r'''(["'`])([^"'`\n]{0,400})\1'''), (m) {
      final inner = m[2]!;
      return RegExp(r'^[\w$.\-\[\]]{0,40}$').hasMatch(inner) ? m[0]! : '${m[1]}…${m[1]}';
    });
    return s.length > max ? s.substring(0, max) : s;
  }

  static String _hash(String s) {
    var h = 5381;
    for (final c in utf8.encode(s)) {
      h = ((h << 5) + h + c) & 0xFFFFFFFF;
    }
    return h.toRadixString(16);
  }

  /// İmza: maskelenmiş ileti + yığının ilk iki çerçevesi (satır/sütun hariç).
  static String signature(String msg, String stack) {
    final frames = stack
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(2)
        .map((l) => l.trim().replaceAll(RegExp(r'[: ]\d+(:\d+)?\)?'), '').replaceAll(RegExp(r'\s+'), ' '))
        .join('|');
    return _hash('${sanitize(msg, 300)}|$frames');
  }

  static Future<bool> enabled() async =>
      (await SharedPreferences.getInstance()).getBool('fc.crash.enabled') ?? true;

  static Future<void> setEnabled(bool v) async =>
      (await SharedPreferences.getInstance()).setBool('fc.crash.enabled', v);

  static String _day() => now().toIso8601String().substring(0, 10);

  static Future<int> sentToday() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('fc.crash.day') == _day() ? (p.getInt('fc.crash.n') ?? 0) : 0;
  }

  /// Gönderilmeli mi? Gönderecekse sayaçları günceller.
  static Future<bool> decide(String sig) async {
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool('fc.crash.enabled') ?? true)) return false;
    final key = '$kAppVersion:$sig';
    final seen = p.getStringList('fc.crash.seen') ?? <String>[];
    if (seen.contains(key)) return false;
    final today = _day();
    var n = p.getString('fc.crash.day') == today ? (p.getInt('fc.crash.n') ?? 0) : 0;
    if (n >= maxPerDay) return false;
    n++;
    await p.setString('fc.crash.day', today);
    await p.setInt('fc.crash.n', n);
    seen.add(key);
    await p.setStringList('fc.crash.seen', seen.length > 200 ? seen.sublist(seen.length - 200) : seen);
    return true;
  }

  static bool _busy = false;

  /// true: rapor gönderilmek üzere sıraya alındı.
  static Future<bool> report(Object error, StackTrace? stack, {String source = 'ui'}) async {
    if (_busy) return false; // rapor sırasında oluşan hata döngüye girmesin
    _busy = true;
    try {
      final msg = '${error.runtimeType}: $error';
      if (_ignore.hasMatch(msg)) return false;
      final st = (stack ?? StackTrace.empty).toString();
      final sig = signature(msg, st);
      if (!await decide(sig)) return false;
      final text = '[$source] ${sanitize(msg, 600)}'
          '${st.trim().isEmpty ? '' : '\n\n${sanitize(st, 1800)}'}\n\n#$sig';
      await sender(text);
      return true;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }
}
