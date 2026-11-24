// Ekran görüntüleri (yalnız CI "ekran" işi: SCREENS=1). Gerçek yazı tipleriyle çizilir,
// build/screens/*.png olarak yazılır. Normal `flutter test` çalıştırmasında atlanır.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:kalori_hesaplayici/core/app_info.dart';
import 'package:kalori_hesaplayici/core/look.dart';
import 'package:kalori_hesaplayici/data/settings.dart';
import 'package:kalori_hesaplayici/main.dart';
import 'package:kalori_hesaplayici/services/fc_agent.dart';
import 'package:kalori_hesaplayici/services/food_db.dart';
import 'package:kalori_hesaplayici/services/portion_learner.dart';

final _on = Platform.environment['SCREENS'] == '1';
final _k = GlobalKey();

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    final b = File(f).readAsBytesSync();
    l.addFont(Future.value(ByteData.view(b.buffer)));
  }
  await l.load();
}

String _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.isNotEmpty) return env;
  var d = File(Platform.resolvedExecutable).parent;
  while (d.path != d.parent.path) {
    if (File('${d.path}/bin/flutter').existsSync()) return d.path;
    d = d.parent;
  }
  return '';
}

Future<void> _shot(WidgetTester t, String name) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump(const Duration(milliseconds: 100));
  }
  final ro = _k.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await t.runAsync(() async {
    final img = await ro.toImage(pixelRatio: 2.0);
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    File('build/screens/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bd!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!_on) return;
    final tmp = Directory.systemTemp.createTempSync('kalori');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (c) async => tmp.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await _font('Inter', [for (final w in [400, 500, 600, 700]) 'assets/fonts/Inter-$w.ttf']);
    await _font('NotoSansArabic', [for (final w in [400, 500, 600, 700]) 'assets/fonts/NotoSansArabic-$w.ttf']);
    final root = _flutterRoot();
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await _font('MaterialIcons', [icons.path]);
    SharedPreferences.setMockInitialValues({'welcomed': true, 'fc.lastSeenVersion': kAppVersion, 'age': 31});
    await Settings.instance.init();
    await FcLook.instance.init();
    await initializeDateFormatting();
    await FoodDb.instance.load();
    await PortionLearner.instance.init();
    await FcAgent.instance.init(app: kAppId, version: kAppVersion, lang: () => Settings.instance.lang);
  });

  final configs = [('tr', 'falcon', 'dark'), ('ar', 'falcon', 'light'), ('tr', 'klasik', 'light')];
  for (final c in configs) {
    final name = '${c.$1}-${c.$2}-${c.$3}';
    testWidgets(name, (t) async {
      t.view.physicalSize = const Size(412 * 2.0, 892 * 2.0);
      t.view.devicePixelRatio = 2.0;
      Settings.instance.lang = c.$1;
      Settings.instance.welcomed = true;
      FcLook.instance.setScheme(c.$2);
      FcLook.instance.setTheme(c.$3);
      await t.pumpWidget(RepaintBoundary(key: _k, child: const KaloriApp()));
      await _shot(t, '$name-1-ana');
      await t.tap(find.byIcon(Icons.settings_outlined));
      await _shot(t, '$name-2-ayarlar');
      await t.drag(find.byType(ListView).last, const Offset(0, -1700));
      await _shot(t, '$name-3-ayarlar-alt');
      if (c.$1 == 'tr' && c.$2 == 'falcon') {
        Settings.instance.welcomed = false;
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(RepaintBoundary(key: _k, child: const KaloriApp()));
        await _shot(t, '$name-4-rehber-dil');
        await t.tap(find.text('İleri'));
        await _shot(t, '$name-5-rehber-gorunum');
        await t.tap(find.text('İleri'));
        await _shot(t, '$name-6-rehber-anahtar');
        Settings.instance.welcomed = true;
      }
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(minutes: 1));
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    }, skip: !_on);
  }
}
