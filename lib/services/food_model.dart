import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'update_service.dart' show DownloadProgress;

String _sha256(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();

/// Food-specific offline recognition model: Google AIY "food_V1" image
/// classifier (2,023 dishes, Apache-2.0). ~21 MB, so it is not inside the
/// APK: it is downloaded once (automatically on Wi‑Fi, or from Settings)
/// from a pinned GitHub copy and checked with SHA-256.
class FoodModel extends ChangeNotifier {
  FoodModel._();
  static final FoodModel instance = FoodModel._();

  static const fileName = 'aiy_food_V1.tflite';
  static const sizeBytes = 21151551;
  static const sha =
      '03dd6d9129501f97be00775d9e17b5d9ad13be730149352adb8f4ca953b7a650';
  /// Pinned copies of the original TF Hub file (exact commit + SHA-256).
  static const urls = [
    'https://raw.githubusercontent.com/hotg-ai/test-runes/5b4c1175cbc039fb76c91e77a202aed05262c129/image/food/food.tflite',
    'https://raw.githubusercontent.com/wwb-cloud/open-calories/7cef62ffbc5354a55655601b416b256aee38ac6e/assets/models/aiy_food_V1.tflite',
  ];

  DownloadProgress? progress; // non-null while downloading
  String? error;
  bool _busy = false;
  bool get busy => _busy;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'models', fileName));
  }

  /// Path of the verified model, or null if not downloaded yet.
  Future<String?> path() async {
    final f = await _file();
    if (await f.exists() && await f.length() == sizeBytes) return f.path;
    return null;
  }

  Future<bool> get installed async => (await path()) != null;

  /// Downloads quietly when on Wi‑Fi and the model is missing.
  Future<void> autoDownload() async {
    try {
      if (await installed) return;
      final c = await Connectivity().checkConnectivity();
      if (!c.contains(ConnectivityResult.wifi) &&
          !c.contains(ConnectivityResult.ethernet)) {
        return;
      }
      await download();
    } catch (_) {}
  }

  Future<void> delete() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
    notifyListeners();
  }

  Future<bool> download() async {
    if (_busy) return false;
    for (final u in urls) {
      if (await _download(u)) return true;
    }
    return false;
  }

  Future<bool> _download(String url) async {
    if (_busy) return false;
    _busy = true;
    error = null;
    progress = DownloadProgress(0, sizeBytes, 0);
    notifyListeners();
    final f = await _file();
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.part');
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url))
        ..headers['User-Agent'] = 'kalori-hesaplayici';
      final res = await client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw HttpException('model ${res.statusCode}');
      }
      final total = res.contentLength ?? sizeBytes;
      final sink = tmp.openWrite();
      var received = 0, lastBytes = 0, lastTick = 0;
      var speed = 0.0;
      final sw = Stopwatch()..start();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        final ms = sw.elapsedMilliseconds;
        if (ms - lastTick >= 400) {
          speed = (received - lastBytes) / ((ms - lastTick) / 1000);
          lastTick = ms;
          lastBytes = received;
          progress = DownloadProgress(received, total, speed);
          notifyListeners();
        }
      }
      await sink.close();
      final hash = await compute(_sha256, tmp.path);
      if (hash != sha) {
        await tmp.delete();
        throw const FormatException('SHA-256');
      }
      if (await f.exists()) await f.delete();
      await tmp.rename(f.path);
      return true;
    } catch (e) {
      error = e.toString();
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      return false;
    } finally {
      client.close();
      _busy = false;
      progress = null;
      notifyListeners();
    }
  }
}
