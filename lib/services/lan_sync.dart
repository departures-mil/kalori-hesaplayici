import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../data/db.dart';

/// İnternetsiz eşitleme: aynı modeme (Wi-Fi) bağlı iki telefon.
/// Bir telefon "Bekle" der (sunucu olur, 6 haneli kod gösterir), öbürü
/// ağı tarayıp onu bulur ya da adresi elle yazar, kodu girer.
/// İki yön birleşir: eksik kayıt eklenir, aynı kayıtta yeni olan kazanır,
/// hiçbir kayıt üzerine yazılarak kaybolmaz.
class LanSync {
  static const port = 47811;
  static HttpServer? _server;
  static String? _pin;
  static final _events = StreamController<String>.broadcast();

  /// Sunucu tarafında olan biten ("merged:3:1" vb.).
  static Stream<String> get events => _events.stream;
  static bool get hosting => _server != null;
  static String? get pin => _pin;

  /// Bu cihazın Wi-Fi/yerel IPv4 adresleri.
  static Future<List<String>> localIps() async {
    final out = <String>[];
    for (final ni in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      for (final a in ni.addresses) {
        if (!a.isLoopback && _private(a.address)) out.add(a.address);
      }
    }
    return out;
  }

  static bool _private(String ip) =>
      ip.startsWith('192.168.') ||
      ip.startsWith('10.') ||
      RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip);

  static Future<String> startHost() async {
    await stopHost();
    _pin = (100000 + Random.secure().nextInt(900000)).toString();
    final srv = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
    _server = srv;
    srv.listen(_handle, onError: (_) {});
    return _pin!;
  }

  static Future<void> stopHost() async {
    final s = _server;
    _server = null;
    _pin = null;
    await s?.close(force: true);
  }

  static Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      if (req.method == 'GET' && req.uri.path == '/kalori-ping') {
        res.headers.contentType = ContentType.json;
        res.write(jsonEncode({'app': 'kalori', 'name': Platform.localHostname}));
      } else if (req.method == 'POST' && req.uri.path == '/kalori-esitle') {
        if (req.headers.value('x-pin') != _pin) {
          res.statusCode = HttpStatus.forbidden;
        } else {
          final body = await utf8.decodeStream(req);
          final theirs = jsonDecode(body) as Map<String, dynamic>;
          // önce kendi verimizi alıp gönderiyoruz, sonra onlarınkini birleştiriyoruz:
          // böylece karşı taraf da bizde olan her şeyi alır.
          final mine = await AppDb.instance.exportAll();
          final r = await AppDb.instance.mergeAll(theirs);
          res.headers.contentType = ContentType.json;
          res.add(utf8.encode(jsonEncode(mine)));
          _events.add('merged:${r['added']}:${r['updated']}');
        }
      } else {
        res.statusCode = HttpStatus.notFound;
      }
    } catch (e) {
      res.statusCode = HttpStatus.internalServerError;
      _events.add('error:$e');
    }
    await res.close();
  }

  /// Aynı ağda bekleyen telefonları bulur (x.x.x.1–254, kısa süreli denemeler).
  static Future<List<String>> discover({void Function(double)? progress}) async {
    final found = <String>[];
    final mine = await localIps();
    for (final ip in mine) {
      final base = ip.substring(0, ip.lastIndexOf('.') + 1);
      final targets = [for (var i = 1; i < 255; i++) '$base$i']..remove(ip);
      var done = 0;
      const batch = 32;
      for (var i = 0; i < targets.length; i += batch) {
        final part = targets.sublist(i, min(i + batch, targets.length));
        await Future.wait(part.map((t) async {
          if (await _ping(t)) found.add(t);
        }));
        done += part.length;
        progress?.call(done / targets.length);
      }
    }
    return found;
  }

  static Future<bool> _ping(String host) async {
    final c = HttpClient()..connectionTimeout = const Duration(milliseconds: 700);
    try {
      final rq = await c.getUrl(Uri.parse('http://$host:$port/kalori-ping'))
          .timeout(const Duration(milliseconds: 900));
      final rs = await rq.close().timeout(const Duration(milliseconds: 900));
      final txt = await utf8.decodeStream(rs);
      return txt.contains('"kalori"');
    } catch (_) {
      return false;
    } finally {
      c.close(force: true);
    }
  }

  /// Karşı telefona bağlanıp iki yönlü eşitler. Dönen: {added, updated}.
  static Future<Map<String, int>> syncWith(String host, String pin) async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final mine = await AppDb.instance.exportAll();
      final rq = await c.postUrl(Uri.parse('http://${host.trim()}:$port/kalori-esitle'));
      rq.headers.set('x-pin', pin.trim());
      rq.headers.contentType = ContentType.json;
      rq.add(utf8.encode(jsonEncode(mine)));
      final rs = await rq.close().timeout(const Duration(seconds: 60));
      if (rs.statusCode == HttpStatus.forbidden) throw const LanSyncError('pin');
      if (rs.statusCode != 200) throw LanSyncError('http ${rs.statusCode}');
      final theirs = jsonDecode(await utf8.decodeStream(rs)) as Map<String, dynamic>;
      return AppDb.instance.mergeAll(theirs);
    } on SocketException {
      throw const LanSyncError('unreachable');
    } on TimeoutException {
      throw const LanSyncError('unreachable');
    } finally {
      c.close(force: true);
    }
  }
}

class LanSyncError implements Exception {
  final String code;
  const LanSyncError(this.code);
  @override
  String toString() => 'LanSyncError($code)';
}
