# Kalori Hesaplayıcı

Fotoğraftan kalori analizi + ajanda. **Yalnız Android APK** (Flutter; masaüstü sürümü YOK — Milen'in kuralı).
Android projesi depoda yok: CI `flutter create` ile üretir, `tool/patch_android.py` yamalar
(izinler, minSdk 23, paket `com.departures.kalori` DEĞİŞMEZ, imza, MainActivity kanalları `kalori/window` + `kalori/app`).

## Ortak çekirdek (v1.1.0'dan beri)
- `cekirdek/VERSION` = ortak-cekirdek commit'i. `cekirdek/schemes.js` → `node tool/gen_fc_tokens.js` → `lib/core/fc_tokens.dart`
  (8 şema; `klasik` = 1.0.x pembe görünümü, açık modda birebir). CI `--check` ile denetler.
- `lib/core/look.dart` (FcLook: şema, koyu/açık/otomatik, yazı boyutu), `lib/core/theme.dart` (AppColors şemadan gelir).
  Yazı tipleri `assets/fonts` (Inter + Noto Sans Arabic).
- `lib/core/fcdelta.dart` = çekirdek `delta/dart/fcdelta.dart` kopyası. `lib/services/update_service.dart`:
  `releases/latest/download/latest.json` → kanal `android` → kurulu APK (`kalori/app` apkInfo → sourceDir) + FCD1 yaması,
  SHA-256; olmazsa tam APK. Açılışta bir kez denetlenir, varsa pencere.
- `fc_contact.dart` (tek gelen kutusu, SPEC alanları, kuyruk), `fc_crash.dart` (≤5/gün), `data/news.dart` (neler yeni, EN ÜSTTE yeni sürüm),
  Ayarlar sırası: Görünüm … Kullanım Limitleri, Asistan Agent, Hata raporu, Arşiv, **Admin ile iletişim EN SON**.
- Wi‑Fi eşitleme (`lan_sync.dart`, `db.dart mergeAll`): kalıcı silme yok (deleted=1 → Arşiv), ezilen yerel hâl `cakisma` tablosuna.

## 1.1.1 eklemeleri
- `services/text_entry.dart` (yazarak/sesle: önce kullanıcının anahtarıyla `OnlineAnalyzer.parseText`, yoksa cihazda ayrıştırma),
  `screens/quick_text_screen.dart`, `saved_screen.dart` (favoriler / sık / tarifler), `recipe_screen.dart`, `cycle_screen.dart`.
- DB v4: `saved` (fav / recipe, uid) ve `period` (adet başlangıçları) tabloları; ikisi de `exportAll/mergeAll` ile eşitlenir, kalıcı silme yok.
- `services/native_bridge.dart` ↔ `kalori/app` kanalı: speech, notifPermission, reminders, widget, saveDoc/openDoc (Drive yedeği), dynamicColors.
  Kotlin tarafı (`KaloriAlarms`, `ReminderReceiver`, `BootReceiver`, `KaloriWidget`) ve widget kaynakları `tool/patch_android.py` içinde üretilir.
- APK küçültme: `abiFilters` = armeabi-v7a + arm64-v8a (patch_android.py).
- Yeni metinler `lib/l10n/strings_v12.dart` (üç dilde aynı anahtarlar; test denetler).

## Kurallar (Milen)
- Yazışma dili Türkçe; arayüz tr/en/ar (ar sağdan sola). Yeni metin: `lib/l10n/strings_fc.dart` üç dilde (test denetler).
- Yapay zekâ: her kullanıcı KENDİ anahtarını girer (ilk açılış rehberi + Ayarlar). Sahibin anahtarı ASLA gömülmez, `--dart-define` yok.
- Sürüm X.Y.Z, etiket `vX.Y.Z`. Yükseltirken: `pubspec.yaml` (`version: X.Y.Z+<versionCode+1>`), `lib/core/app_info.dart`,
  `lib/data/news.dart` (en üste), `release-notes.json`. `flutter test` tutarlılığı denetler.
- İmza: yalnız secret'lar `ANDROID_KEYSTORE_B64`, `ANDROID_KEYSTORE_PASS`, `ANDROID_KEY_PASS`, `ANDROID_KEY_ALIAS`
  (geçiş için eski `KEYSTORE_BASE64`/`KEYSTORE_PASSWORD`/`KEY_ALIAS` da okunur). Varsayılan şifre/geçici anahtar YOK.
  CI, APK sertifikasını `EXPECTED_CERT` (v1.0.9–v1.0.12 APK anahtarı) ile karşılaştırır; farklıysa yayın olmaz.
- Kullanıcıya APK dosyası gönderme; güncelleme uygulamanın içinden.

## Yayın
`.github/workflows/release.yml`: test (`gen_fc_tokens --check`, `flutter analyze --no-fatal-infos`, `flutter test`) → imzalı APK
→ `departures-mil/ortak-cekirdek` reusable-release (latest.json, son 5 sürümden yamalar). main push/dal: yalnız test+derleme.
Release: `gh api -X POST repos/departures-mil/kalori-hesaplayici/actions/workflows/release.yml/dispatches -f ref=main`.
Asset adı `KaloriHesaplayici-vX.Y.Z.apk` kalır: ≤1.0.12 eski güncelleyici GitHub API'de `.apk` ile biten ilk asset'i indirir.
