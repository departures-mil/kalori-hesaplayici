import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kalori_hesaplayici/core/app_info.dart';
import 'package:kalori_hesaplayici/core/fc_tokens.dart';
import 'package:kalori_hesaplayici/core/fcdelta.dart';
import 'package:kalori_hesaplayici/core/look.dart';
import 'package:kalori_hesaplayici/core/theme.dart';
import 'package:kalori_hesaplayici/data/merge_rule.dart';
import 'package:kalori_hesaplayici/data/news.dart';
import 'package:kalori_hesaplayici/data/settings.dart';
import 'package:kalori_hesaplayici/l10n/strings_fc.dart';
import 'package:kalori_hesaplayici/services/fc_contact.dart';
import 'package:kalori_hesaplayici/services/fc_crash.dart';
import 'package:kalori_hesaplayici/services/update_service.dart';
import 'package:kalori_hesaplayici/widgets/look_picker.dart';

const _sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _shaP = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

Map<String, dynamic> _latest({String v = '1.2.0', String min = '1.0.0', Map<String, dynamic>? patches}) => {
      'schema': 1,
      'app': 'kalori-hesaplayici',
      'version': v,
      'minVersion': min,
      'notes': {'tr': 'Notlar', 'en': 'Notes', 'ar': 'ملاحظات'},
      'assets': {
        'android': {
          'file': 'KaloriHesaplayici-v$v.apk',
          'size': 1000,
          'sha256': _sha,
          'patches': patches ??
              {
                kAppVersion: {'file': 'KaloriHesaplayici-android.patch-from-$kAppVersion.bin', 'size': 10, 'sha256': _shaP}
              },
        }
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('sürüm', () {
    test('pubspec = kAppVersion = neler yeni (en üstte)', () {
      final pub = File('pubspec.yaml').readAsStringSync();
      final m = RegExp(r'^version:\s*([0-9.]+)\+(\d+)', multiLine: true).firstMatch(pub)!;
      expect(m.group(1), kAppVersion);
      expect(int.parse(m.group(2)!), greaterThanOrEqualTo(14)); // 1.0.12+13'ten büyük olmalı
      expect(kNews.first.v, kAppVersion);
      for (final l in ['tr', 'en', 'ar']) {
        expect(kNews.first.items[l], isNotEmpty, reason: l);
      }
    });

    test('uygulamaya gömülü yapay zekâ anahtarı yok', () {
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        final t = f.readAsStringSync();
        expect(t.contains('kBundled'), isFalse, reason: f.path);
        expect(t.contains("String.fromEnvironment('GEMINI"), isFalse, reason: f.path);
        expect(RegExp(r'sk-(proj|ant)-[A-Za-z0-9_-]{20,}').hasMatch(t), isFalse, reason: f.path);
      }
      final wf = Directory('.github/workflows').listSync().whereType<File>();
      for (final f in wf) {
        final t = f.readAsStringSync();
        expect(t.contains('--dart-define'), isFalse, reason: f.path);
        expect(t.contains('genkeypair'), isFalse, reason: f.path);
      }
    });
  });

  group('görünüm', () {
    test('tüm şemalar × koyu/açık tüm renk tokenlarını tanımlar', () {
      expect(kFcSchemeIds.first, 'falcon');
      expect(kFcSchemeIds, contains('klasik'));
      for (final id in kFcSchemeIds) {
        for (final mode in ['dark', 'light']) {
          final t = kFcTokens[id]![mode]!;
          for (final k in kFcColorTokens) {
            expect(t.containsKey(k), isTrue, reason: '$id.$mode.$k');
          }
        }
        for (final l in ['tr', 'en', 'ar']) {
          expect(kFcSchemeLabels[id]![l], isNotEmpty);
        }
      }
      expect(kFcTokens['falcon']!['dark']!['accent'], const Color(0xFF22D3EE));
      expect(kFcTokens['falcon']!['light']!['accent'], const Color(0xFF0891B2));
    });

    test('klasik açık = eski renkler birebir', () {
      final p = FcPalette('klasik', false);
      expect(p.rose, const Color(0xFFE75480));
      expect(p.lavender, const Color(0xFF9B7EDE));
      expect(p.bg, const Color(0xFFFFF7FA));
      expect(p.text, const Color(0xFF3B2A3F));
      expect(p.muted, const Color(0xFF7A6A80));
      expect(p.roseSoft, const Color(0xFFF8A5C2));
      expect(p.lavenderSoft, const Color(0xFFD9CCF5));
    });

    test('varsayılan falcon koyu; yazı boyutu sınırları', () async {
      await FcLook.instance.init();
      expect(FcLook.instance.scheme, 'falcon');
      expect(FcLook.instance.theme, 'dark');
      expect(FcLook.clampScale(3), FcLook.maxScale);
      expect(FcLook.clampScale(0.1), FcLook.minScale);
      FcLook.instance.setScheme('klasik');
      FcLook.instance.setTheme('light');
      expect(AppColors.rose, const Color(0xFFE75480));
      FcLook.instance.setScheme('yok-boyle-sema');
      expect(FcLook.instance.scheme, 'klasik');
      FcLook.instance.setScheme('falcon');
      FcLook.instance.setTheme('dark');
    });

    testWidgets('şema seçici: dokununca şema değişir', (t) async {
      await FcLook.instance.init();
      await Settings.instance.init();
      Settings.instance.lang = 'en';
      await t.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Scaffold(body: SingleChildScrollView(child: LookPicker())),
      ));
      expect(find.text('Ocean'), findsOneWidget);
      await t.tap(find.text('Ocean'));
      await t.pump();
      expect(FcLook.instance.scheme, 'okyanus');
      await t.tap(find.text('Light'));
      await t.pump();
      expect(FcLook.instance.dark, isFalse);
      FcLook.instance.setScheme('falcon');
      FcLook.instance.setTheme('dark');
    });
  });

  group('güncelleme', () {
    test('yama planı: kurulu sürüme ait yama seçilir', () {
      final p = UpdateService.planFrom(_latest(), kAppVersion)!;
      expect(p.version, '1.2.0');
      expect(p.full.file, 'KaloriHesaplayici-v1.2.0.apk');
      expect(p.patch!.sha256, _shaP);
      expect(p.baseUrl, 'https://github.com/departures-mil/kalori-hesaplayici/releases/download/v1.2.0/');
      expect(p.note('ar'), 'ملاحظات');
    });

    test('yama yoksa ya da minVersion altındaysa tam APK', () {
      expect(UpdateService.planFrom(_latest(patches: {}), kAppVersion)!.patch, isNull);
      expect(UpdateService.planFrom(_latest(min: '9.0.0'), kAppVersion)!.patch, isNull);
    });

    test('yeni sürüm yok / bozuk manifest → null', () {
      expect(UpdateService.planFrom(_latest(v: kAppVersion), kAppVersion), isNull);
      expect(UpdateService.planFrom(_latest(v: '1.0.9'), kAppVersion), isNull);
      final bad = _latest();
      (bad['assets']['android'] as Map)['sha256'] = 'xyz';
      expect(UpdateService.planFrom(bad, kAppVersion), isNull);
      expect(UpdateService.planFrom({'version': '9.9.9', 'assets': {}}, kAppVersion), isNull);
    });

    test('sürüm karşılaştırma', () {
      expect(UpdateService.cmp('1.1.0', '1.0.12'), greaterThan(0));
      expect(UpdateService.cmp('v1.0.12', '1.0.12'), 0);
      expect(UpdateService.cmp('1.0.9', '1.0.10'), lessThan(0));
    });

    test('ilerleme metni değerleri', () {
      const p = UpdateProgress(5 * 1048576, 20 * 1048576, 2.5 * 1048576, true);
      expect(p.percent, 25);
      expect(UpdateProgress.mb(p.remaining), '15.0');
      expect(UpdateProgress.mb(p.speedBps), '2.5');
      expect(kStringsFc['tr']!['upd_patch'], 'yalnızca değişen kısımlar');
      expect(kStringsFc['en']!['upd_patch'], 'changed parts only');
      expect(kStringsFc['ar']!['upd_patch'], 'الأجزاء المتغيرة فقط');
    });

    test('FCD1 yaması uygulanır ve SHA-256 doğrulanır (Node fcdelta ile üretilmiş)', () async {
      final tmp = Directory.systemTemp.createTempSync('fcd');
      final out = '${tmp.path}/out.bin';
      final h = FcDelta.applySync('test/fixtures/old.bin', 'test/fixtures/patch.bin', out);
      expect(h.dstSha256Hex, '82c639e512554c6b82388734b59ae684479b771e7de100d7fa9dcba62c54dc12');
      expect(File(out).readAsBytesSync(), File('test/fixtures/new.bin').readAsBytesSync());
      // yanlış kaynak → hata, çıktı oluşmaz
      final out2 = '${tmp.path}/out2.bin';
      expect(() => FcDelta.applySync('test/fixtures/new.bin', 'test/fixtures/patch.bin', out2),
          throwsA(isA<FcDeltaException>()));
      expect(File(out2).existsSync(), isFalse);
      tmp.deleteSync(recursive: true);
    });
  });

  group('iletişim ve çökme raporu', () {
    test('SPEC alanları, hepsi stringValue', () async {
      FcContact.lang = () => 'ar';
      final f = await FcContact.fields(tur: 'oneri', mesaj: 'merhaba', iletisim: 'a@b.co');
      expect(f.keys.toSet(),
          {'tur', 'uygulama', 'surum', 'platform', 'dil', 'mesaj', 'zaman', 'cihaz', 'iletisim'});
      expect(f['uygulama'], 'kalori-hesaplayici');
      expect(f['surum'], kAppVersion);
      expect(f['dil'], 'ar');
      expect(f['cihaz'], matches(RegExp(r'^[0-9a-f]{18}$')));
      final f2 = await FcContact.fields(tur: 'hata', mesaj: 'x');
      expect(f2.containsKey('iletisim'), isFalse);
      expect(f2['cihaz'], f['cihaz']); // aynı cihaz kimliği
      final body = FcContact.firestoreBody(f);
      for (final v in (body['fields'] as Map).values) {
        expect((v as Map).keys.single, 'stringValue');
      }
      FcContact.lang = () => 'tr';
    });

    test('maskeleme', () {
      final s = FcCrash.sanitize(
          'ali@ornek.com /home/ayse/x /storage/emulated/0/DCIM/a.jpg https://x.io/a?key=123 1234567 "gizli kayıt metni"');
      expect(s, isNot(contains('ali@')));
      expect(s, isNot(contains('ayse')));
      expect(s, isNot(contains('DCIM')));
      expect(s, isNot(contains('key=')));
      expect(s, isNot(contains('1234567')));
      expect(s, isNot(contains('gizli')));
    });

    test('günde en çok 5 rapor, aynı imza bir kez', () async {
      final sent = <String>[];
      FcCrash.sender = (t) async {
        sent.add(t);
        return 'sent';
      };
      FcCrash.now = () => DateTime(2026, 11, 24, 12);
      final st = StackTrace.current;
      expect(await FcCrash.report(StateError('a'), st), isTrue);
      expect(await FcCrash.report(StateError('a'), st), isFalse); // aynı imza
      expect(FcCrash.signature('E: x', '#0 f (a.dart:1:2)\n#1 g (b.dart:3:4)'),
          FcCrash.signature('E: x', '#0 f (a.dart:9:9)\n#1 g (b.dart:7:7)'));
      for (var i = 0; i < 6; i++) {
        await FcCrash.report(StateError('hata $i x'), null);
      }
      expect(sent.length, FcCrash.maxPerDay);
      expect(sent.first, contains('#'));
      FcCrash.now = () => DateTime(2026, 11, 25, 12);
      expect(await FcCrash.report(StateError('yeni gün'), null), isTrue);
      expect(await FcCrash.report(const SocketException('x'), null), isFalse); // ağ hatası çökme değil
      await FcCrash.setEnabled(false);
      expect(await FcCrash.report(StateError('kapalı'), null), isFalse);
      FcCrash.now = DateTime.now;
    });
  });

  group('eşitleme kuralı (hiçbir kayıt silinmez / izsiz ezilmez)', () {
    test('karar tablosu', () {
      expect(mergeDecision(exists: false, mineUpdated: 0, theirsUpdated: 5), MergeAction.insert);
      expect(mergeDecision(exists: true, mineUpdated: 5, theirsUpdated: 9), MergeAction.backupAndReplace);
      expect(mergeDecision(exists: true, mineUpdated: 9, theirsUpdated: 5), MergeAction.keep);
      expect(mergeDecision(exists: true, mineUpdated: 5, theirsUpdated: 5), MergeAction.keep);
    });

    test('db.dart: kalıcı silme yok, ezilen kayıt yedeklenir', () {
      final src = File('lib/data/db.dart').readAsStringSync();
      expect(RegExp(r"\.delete\(\s*'entries'").hasMatch(src), isFalse);
      expect(src.contains('DELETE FROM'), isFalse);
      expect(src.contains('_backup(tx'), isTrue);
    });
  });

  test('yeni metinler üç dilde', () {
    final tr = kStringsFc['tr']!.keys.toSet();
    expect(kStringsFc['en']!.keys.toSet(), tr);
    expect(kStringsFc['ar']!.keys.toSet(), tr);
  });

  test('Ayarlar: Admin ile iletişim EN SONDA', () {
    final src = File('lib/screens/settings_screen.dart').readAsStringSync();
    final build = src.substring(src.indexOf('Widget build('), src.indexOf('Future<void> _testAi'));
    final sections = RegExp(r"_section\(([^)]*)\)").allMatches(build).map((m) => m.group(1)).toList();
    expect(sections.last, "s['contact_title']");
    expect(sections.first, "s['look']");
  });
}
