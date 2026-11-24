# Kalori Hesaplayıcı

Fotoğraftan kalori analizi yapan, ajanda ve günlük toplam takibi tutan Android uygulaması.

- Online analiz: Gemini (yedek: OpenAI / Claude)
- Çevrimdışı analiz: ML Kit + yerel besin tablosu (`assets/data/foods.json`)
- Barkod okuma (Open Food Facts)
- Türkçe / English / العربية
- Güncelleme: GitHub Releases `latest.json` (ortak çekirdek), yalnızca değişen kısımlar (FCD1 yaması), SHA-256 doğrulamalı
- Görünüm: Falcon şemaları (eski görünüm "Klasik"), koyu/açık/otomatik, yazı boyutu
- Yapay zekâ: her kullanıcı kendi anahtarını girer (uygulamada hazır anahtar yok)
- Eşitleme: besin tablosu GitHub'dan; Wi‑Fi ile iki telefon arasında (kayıt silinmez, çakışma yedeklenir)

APK, Actions → release (main, workflow_dispatch) ile derlenip `v<sürüm>` olarak yayınlanır. Ayrıntı: `CLAUDE.md`.

## Asistan Agent (1.0.12)
`lib/services/fc_agent.dart` + `fc_agent_dil.dart` (= ortak-cekirdek/flutter): çalışmayı sayılarla izler (süre, sekmeler, saatler), çevrim dışı
kurallar + kullanıcının kendi Gemini anahtarıyla öneri; üst çubukta ✦ (okunmamış sayısı), Ayarlar'da kart (iletişimin önünde), uygulama içi bildirim.
