import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/settings.dart';

class UpdateInfo {
  final String version; // e.g. 1.0.3
  final String apkUrl;
  final int size;
  final String notes;
  UpdateInfo(this.version, this.apkUrl, this.size, this.notes);
}

class DownloadProgress {
  final int received;
  final int total;
  final double speedBps; // bytes per second
  DownloadProgress(this.received, this.total, this.speedBps);

  double get fraction => total > 0 ? received / total : 0;
  int get remaining => total > received ? total - received : 0;

  static String mb(num bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';
  String get speedText => speedBps >= 1048576
      ? '${(speedBps / 1048576).toStringAsFixed(1)} MB/s'
      : '${(speedBps / 1024).toStringAsFixed(0)} KB/s';
}

class UpdateService {
  static Future<String> currentVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  static int _cmp(String a, String b) {
    final x = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final y = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d;
    }
    return 0;
  }

  /// Returns the latest release if newer than the installed version.
  static Future<UpdateInfo?> check() async {
    final uri = Uri.parse(
        'https://api.github.com/repos/$kGithubOwner/$kGithubRepo/releases/latest');
    final res = await http.get(uri, headers: {
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'kalori-hesaplayici'
    }).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw HttpException('GitHub ${res.statusCode}');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (j['tag_name'] as String).replaceFirst(RegExp(r'^v'), '');
    final assets = (j['assets'] as List).cast<Map<String, dynamic>>();
    final apk = assets.firstWhere(
      (a) => (a['name'] as String).endsWith('.apk'),
      orElse: () => {},
    );
    if (apk.isEmpty) return null;
    final cur = await currentVersion();
    if (_cmp(tag, cur) <= 0) return null;
    return UpdateInfo(tag, apk['browser_download_url'] as String,
        (apk['size'] as num).toInt(), (j['body'] as String?) ?? '');
  }

  static Future<File> download(
    UpdateInfo info,
    void Function(DownloadProgress) onProgress,
  ) async {
    final dir = await getExternalStorageDirectory() ??
        await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'update-${info.version}.apk'));
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(info.apkUrl))
        ..headers['User-Agent'] = 'kalori-hesaplayici';
      final res = await client.send(req);
      if (res.statusCode != 200) {
        throw HttpException('download ${res.statusCode}');
      }
      final total = res.contentLength ?? info.size;
      final sink = file.openWrite();
      var received = 0;
      final sw = Stopwatch()..start();
      var lastTick = 0;
      var lastBytes = 0;
      var speed = 0.0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        final ms = sw.elapsedMilliseconds;
        if (ms - lastTick >= 500) {
          speed = (received - lastBytes) / ((ms - lastTick) / 1000);
          lastTick = ms;
          lastBytes = received;
          onProgress(DownloadProgress(received, total, speed));
        }
      }
      await sink.close();
      onProgress(DownloadProgress(received, total, speed));
      return file;
    } finally {
      client.close();
    }
  }

  static Future<void> install(File apk) async {
    await OpenFilex.open(apk.path,
        type: 'application/vnd.android.package-archive');
  }
}
