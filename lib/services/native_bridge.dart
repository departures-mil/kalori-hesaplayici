import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 1.1.1: Android tarafı (MainActivity `kalori/app` kanalı; `tool/patch_android.py` yazar).
/// Konuşmadan yazıya, hatırlatmalar, ana ekran widget'ı, dosya kaydet/aç
/// (Google Drive dahil sistem seçicisi) ve Material You renkleri.
/// Kanal yoksa (test, eski derleme) her çağrı sessizce null/false döner.
class NativeBridge {
  static const _ch = MethodChannel('kalori/app');

  static Future<T?> _call<T>(String m, [Object? args]) async {
    if (kIsWeb) return null;
    try {
      return await _ch.invokeMethod<T>(m, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Sistem konuşma tanıma penceresi. [lang]: tr / en / ar. İptal → null.
  static Future<String?> speech(String lang) => _call<String>('speech', {
        'lang': switch (lang) {
          'tr' => 'tr-TR',
          'ar' => 'ar-SA',
          _ => 'en-US',
        },
      });

  /// Bildirim izni (Android 13+). Verildiyse true.
  static Future<bool> notifPermission() async =>
      await _call<bool>('notifPermission') ?? false;

  /// Bütün hatırlatmaları yeniden kurar. Her biri: id, hour, minute, title, body,
  /// kind ('meal:breakfast' / 'water' …). Boş liste = hepsi iptal.
  static Future<void> setReminders(List<Map<String, Object>> list) =>
      _call<void>('reminders', {'list': jsonEncode(list)});

  /// Ana ekran widget'ı ve akıllı hatırlatmalar için bugünün özeti.
  static Future<void> widgetUpdate(Map<String, Object> data) =>
      _call<void>('widget', {'json': jsonEncode(data)});

  /// Sistem "Kaydet" penceresi (Google Drive, Dosyalar…). Kaydedildiyse true.
  static Future<bool> saveDocument(String name, String content) async =>
      await _call<bool>('saveDoc', {'name': name, 'content': content}) ?? false;

  /// Sistem "Aç" penceresi; seçilen JSON dosyasının metni.
  static Future<String?> openDocument() => _call<String>('openDoc');

  /// Android 12+ Material You renkleri (ARGB). Desteklenmiyorsa null.
  static Future<Map<String, int>?> dynamicColors() async {
    final m = await _call<Map>('dynamicColors');
    if (m == null || m.isEmpty) return null;
    return m.map((k, v) => MapEntry(k as String, (v as num).toInt()));
  }
}
