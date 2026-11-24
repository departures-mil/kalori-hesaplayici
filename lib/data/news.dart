/// "Neler yeni" — EN ÜSTTE en yeni sürüm (test: kNews.first.v == kAppVersion).
/// Güncellemeden sonraki ilk açılışta gösterilir; Ayarlar → Güncelle'den de açılır.
class NewsItem {
  final String v;
  final Map<String, List<String>> items;
  const NewsItem(this.v, this.items);
}

const List<NewsItem> kNews = [
  NewsItem('1.1.0', {
    'tr': [
      'Yeni Falcon görünümü: 8 renk şeması (eski pembe görünüm "Klasik" olarak duruyor), koyu / açık / otomatik tema ve yazı boyutu.',
      'Güncelleme artık yalnızca değişen kısımları indiriyor; yüzde, MB, kalan ve hız gösteriliyor, dosya SHA-256 ile doğrulanıyor.',
      'Güvenlik: uygulamada hiçbir hazır yapay zekâ anahtarı yok; ilk açılışta kendi ücretsiz anahtarınızı girebilirsiniz.',
      'Otomatik hata raporu (yalnızca hata metni; kayıtlarınız asla gönderilmez), sağlayıcıya göre yapay zekâ kullanım sayacı.',
      'Wi‑Fi eşitlemesinde üzerine yazılan eski kayıtlar artık çakışma yedeğine alınıyor; silinenler Arşiv\'den geri getirilebilir.',
    ],
    'en': [
      'New Falcon look: 8 colour schemes (the old pink look stays as "Classic"), dark / light / auto theme and text size.',
      'Updates now download only the changed parts; percent, MB, remaining and speed are shown and the file is verified with SHA-256.',
      'Security: the app contains no built-in AI key; enter your own free key on first start.',
      'Automatic error reports (error text only; your records are never sent) and an AI usage counter per provider.',
      'Older records overwritten during Wi‑Fi sync are now kept as conflict backups; deleted ones can be restored from the Archive.',
    ],
    'ar': [
      'مظهر فالكون الجديد: ثمانية أنظمة ألوان (يبقى المظهر الوردي القديم باسم «كلاسيكي»)، سمة داكنة / فاتحة / تلقائية وحجم الخط.',
      'يُنزّل التحديث الآن الأجزاء المتغيرة فقط مع عرض النسبة والحجم والمتبقي والسرعة، ويُتحقق من الملف ببصمة SHA-256.',
      'الأمان: لا يحتوي التطبيق على أي مفتاح ذكاء اصطناعي جاهز؛ أدخل مفتاحك المجاني عند التشغيل الأول.',
      'تقارير أخطاء تلقائية (نص الخطأ فقط؛ لا تُرسل سجلاتك أبداً) وعدّاد استخدام الذكاء الاصطناعي لكل مزوّد.',
      'تُحفظ السجلات القديمة التي استُبدلت أثناء مزامنة Wi‑Fi كنسخ تعارض احتياطية، ويمكن استعادة المحذوفة من الأرشيف.',
    ],
  }),
];
