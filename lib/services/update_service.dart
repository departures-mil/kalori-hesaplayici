import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/app_info.dart';
import '../core/fcdelta.dart';

/// Ortak çekirdek güncelleyicisi (SPEC.md): GitHub Releases `latest.json` → kanal `android`.
/// Önce kurulu APK'ya (applicationInfo.sourceDir) FCD1 yaması uygulanır ("yalnızca değişen
/// kısımlar"), sonuç SHA-256 ile doğrulanır; yama yoksa / tutmazsa otomatik tam APK indirilir.
class UpdateAsset {
  final String file;
  final int size;
  final String sha256;
  const UpdateAsset(this.file, this.size, this.sha256);
}

class UpdatePlan {
  final String version;
  final Map<String, String> notes;
  final UpdateAsset full;
  final UpdateAsset? patch;
  const UpdatePlan(this.version, this.notes, this.full, this.patch);

  String get baseUrl =>
      'https://github.com/$kRepoOwner/$kRepoName/releases/download/v$version/';
  String note(String lang) => notes[lang] ?? notes['en'] ?? notes['tr'] ?? '';
}

class UpdateProgress {
  final int received;
  final int total;
  final double speedBps;
  final bool patchMode;
  const UpdateProgress(this.received, this.total, this.speedBps, this.patchMode);

  double get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : 0;
  int get remaining => total > received ? total - received : 0;
  int get percent => (fraction * 100).floor();

  static String mb(num bytes) => (bytes / 1048576).toStringAsFixed(1);
}

/// Çevrimdışı besin modeli indirmesi (food_model.dart) için ilerleme.
class DownloadProgress {
  final int received;
  final int total;
  final double speedBps; // bayt/sn
  DownloadProgress(this.received, this.total, this.speedBps);

  double get fraction => total > 0 ? received / total : 0;
  int get remaining => total > received ? total - received : 0;

  static String mb(num bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';
  String get speedText => speedBps >= 1048576
      ? '${(speedBps / 1048576).toStringAsFixed(1)} MB/s'
      : '${(speedBps / 1024).toStringAsFixed(0)} KB/s';
}

class UpdateService {
  static const channel = 'android';
  static const _app = MethodChannel('kalori/app');
  static String get latestUrl =>
      'https://github.com/$kRepoOwner/$kRepoName/releases/latest/download/latest.json';

  static Future<String> currentVersion() async => kAppVersion;

  static int cmp(String a, String b) {
    List<int> n(String v) => v
        .replaceFirst(RegExp(r'^v'), '')
        .split(RegExp(r'[.+-]'))
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final x = n(a), y = n(b);
    for (var i = 0; i < 3; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d;
    }
    return 0;
  }

  /// latest.json → plan (saf işlev; test edilir). Yeni sürüm yoksa null.
  static UpdatePlan? planFrom(Map<String, dynamic> j, String current) {
    final v = '${j['version'] ?? ''}';
    if (v.isEmpty || cmp(v, current) <= 0) return null;
    final assets = j['assets'];
    if (assets is! Map || assets[channel] is! Map) return null;
    final a = Map<String, dynamic>.from(assets[channel] as Map);
    UpdateAsset? asset(Object? m) {
      if (m is! Map) return null;
      final f = '${m['file'] ?? ''}', s = '${m['sha256'] ?? ''}'.toLowerCase();
      final size = (m['size'] as num?)?.toInt() ?? 0;
      if (f.isEmpty || !RegExp(r'^[0-9a-f]{64}$').hasMatch(s)) return null;
      return UpdateAsset(f, size, s);
    }

    final full = asset(a);
    if (full == null) return null;
    final minV = '${j['minVersion'] ?? '0.0.0'}';
    final patches = a['patches'];
    final patch = cmp(current, minV) >= 0 && patches is Map ? asset(patches[current]) : null;
    final notes = <String, String>{};
    if (j['notes'] is Map) {
      (j['notes'] as Map).forEach((k, val) => notes['$k'] = '$val');
    }
    return UpdatePlan(v, notes, full, patch);
  }

  static Future<UpdatePlan?> check() async {
    final res = await http.get(Uri.parse(latestUrl), headers: {
      'User-Agent': 'kalori-hesaplayici',
      'Cache-Control': 'no-cache',
    }).timeout(const Duration(seconds: 20));
    if (res.statusCode == 404) return null; // henüz latest.json'lu sürüm yok
    if (res.statusCode != 200) throw HttpException('GitHub ${res.statusCode}');
    final j = jsonDecode(utf8.decode(res.bodyBytes));
    if (j is! Map) throw const FormatException('latest.json');
    return planFrom(Map<String, dynamic>.from(j), kAppVersion);
  }

  /// Kurulu APK'nın yolu; split APK ise null (yama kullanılmaz).
  static Future<String?> installedApk() async {
    try {
      final m = await _app.invokeMapMethod<String, dynamic>('apkInfo');
      if (m == null || m['split'] == true) return null;
      final path = m['path'] as String?;
      return path != null && File(path).existsSync() ? path : null;
    } catch (_) {
      return null;
    }
  }

  static Future<Directory> _dir() async {
    final base = await getExternalStorageDirectory() ?? await getApplicationSupportDirectory();
    final d = Directory(p.join(base.path, 'updates'));
    await d.create(recursive: true);
    return d;
  }

  /// Açılışta eski indirme kalıntılarını siler.
  static Future<void> cleanup() async {
    try {
      final d = await _dir();
      await for (final f in d.list()) {
        await f.delete(recursive: true);
      }
      final base = await getExternalStorageDirectory();
      if (base != null) {
        await for (final f in base.list()) {
          if (f is File && RegExp(r'update-[\d.]+\.apk$').hasMatch(f.path)) await f.delete();
        }
      }
    } catch (_) {}
  }

  /// İndirir, doğrular, gerekirse yamayı uygular. Dönen dosya kurulmaya hazır APK'dır.
  /// [onFallback]: yama başarısız olup tam pakete geçildiğinde çağrılır.
  static Future<File> obtain(UpdatePlan plan, void Function(UpdateProgress) onProgress,
      {void Function(Object error)? onFallback, void Function()? onVerifying}) async {
    final dir = await _dir();
    final out = File(p.join(dir.path, 'kalori-${plan.version}.apk'));
    final patch = plan.patch;
    if (patch != null) {
      final installed = await installedApk();
      if (installed != null) {
        try {
          final pf = File(p.join(dir.path, 'patch-${plan.version}.bin'));
          final got = await _download(plan.baseUrl + patch.file, pf, patch.size, true, onProgress);
          if (got != patch.sha256) throw const FormatException('yama SHA-256 uyuşmuyor');
          onVerifying?.call();
          final dst = await FcDelta.apply(installed, pf.path, out.path);
          try {
            await pf.delete();
          } catch (_) {}
          if (dst.toLowerCase() != plan.full.sha256) {
            throw const FormatException('sonuç SHA-256 uyuşmuyor');
          }
          return out;
        } catch (e) {
          onFallback?.call(e);
        }
      }
    }
    final got = await _download(plan.baseUrl + plan.full.file, out, plan.full.size, false, onProgress);
    onVerifying?.call();
    if (got != plan.full.sha256) {
      try {
        await out.delete();
      } catch (_) {}
      throw const UpdateVerifyException();
    }
    return out;
  }

  /// Akış halinde indirir, SHA-256'yı yazarken hesaplar (hex döner).
  static Future<String> _download(String url, File dest, int expected, bool patchMode,
      void Function(UpdateProgress) onProgress) async {
    final client = http.Client();
    final part = File('${dest.path}.part');
    try {
      final req = http.Request('GET', Uri.parse(url))..headers['User-Agent'] = 'kalori-hesaplayici';
      final res = await client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw HttpException('download ${res.statusCode}');
      final total = res.contentLength ?? expected;
      final sink = part.openWrite();
      final digestOut = _DigestSink();
      final hasher = sha256.startChunkedConversion(digestOut);
      var received = 0, lastBytes = 0, lastTick = 0;
      var speed = 0.0;
      final sw = Stopwatch()..start();
      onProgress(UpdateProgress(0, total, 0, patchMode));
      await for (final chunk in res.stream.timeout(const Duration(seconds: 60))) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        final ms = sw.elapsedMilliseconds;
        if (ms - lastTick >= 400) {
          final inst = (received - lastBytes) / ((ms - lastTick) / 1000);
          speed = speed == 0 ? inst : speed * 0.6 + inst * 0.4;
          lastTick = ms;
          lastBytes = received;
          onProgress(UpdateProgress(received, total, speed, patchMode));
        }
      }
      await sink.flush();
      await sink.close();
      hasher.close();
      onProgress(UpdateProgress(received, total, speed, patchMode));
      if (await dest.exists()) await dest.delete();
      await part.rename(dest.path);
      return digestOut.value.toString();
    } catch (e) {
      try {
        if (await part.exists()) await part.delete();
      } catch (_) {}
      rethrow;
    } finally {
      client.close();
    }
  }

  /// SHA-256 (hex) — arka planda.
  static Future<String> sha256Of(String path) => Isolate.run(() {
        final b = FcDelta.sha256File(path);
        return b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
      });

  static Future<void> install(File apk) async {
    // Android 8+: "bilinmeyen uygulamaları yükle" izni yoksa sistem ayar ekranı açılır;
    // kullanıcı döndüğünde pencerede "Kur" düğmesiyle yeniden denenir.
    await OpenFilex.open(apk.path, type: 'application/vnd.android.package-archive');
  }
}

class UpdateVerifyException implements Exception {
  const UpdateVerifyException();
  @override
  String toString() => 'SHA-256';
}

class _DigestSink implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
