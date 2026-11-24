# Kalori Hesaplayıcı

Fotoğraftan kalori analizi yapan, ajanda ve günlük toplam takibi tutan Android uygulaması.

- Online analiz: Gemini (yedek: OpenAI / Claude)
- Çevrimdışı analiz: ML Kit + yerel besin tablosu (`assets/data/foods.json`)
- Barkod okuma (Open Food Facts)
- Türkçe / English / العربية
- Güncelleme: GitHub Releases üzerinden uygulama içinden tek tuşla
- Eşitleme: besin tablosu GitHub'dan güncellenir

APK her `main` push'unda GitHub Actions ile derlenip `v<sürüm>` olarak yayınlanır.
Sürüm `pubspec.yaml` içindeki `version:` satırından okunur.

## Asistan Agent (1.0.12)
`lib/services/fc_agent.dart` + `fc_agent_dil.dart` (= ortak-cekirdek/flutter): çalışmayı sayılarla izler (süre, sekmeler, saatler), çevrim dışı
kurallar + kullanıcının kendi Gemini anahtarıyla öneri; üst çubukta ✦ (okunmamış sayısı), Ayarlar'da kart (iletişimin önünde), uygulama içi bildirim.
