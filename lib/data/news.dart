/// "Neler yeni" — EN ÜSTTE en yeni sürüm (test: kNews.first.v == kAppVersion).
/// Güncellemeden sonraki ilk açılışta gösterilir; Ayarlar → Güncelle'den de açılır.
class NewsItem {
  final String v;
  final Map<String, List<String>> items;
  const NewsItem(this.v, this.items);
}

const List<NewsItem> kNews = [
  NewsItem('1.1.1', {
    'tr': [
      'Yazarak ya da sesle ekle: "1 kase mercimek çorbası, 2 dilim ekmek" demen yeterli (Türkçe, İngilizce, Arapça; internetsiz de çalışır).',
      'Favoriler, sık yenenler ve tariflerim: ev yemeğinin malzemelerini gir, porsiyon başına kaloriyi uygulama hesaplasın. Dünkü öğünü tek dokunuşla tekrar ekle.',
      'Kişisel hedef ilk açılışta (Mifflin-St Jeor), güvenli alt sınırla. Ana sayfada makro çubukları, istatistikte makro halkaları, su grafiği ve haftalık / aylık rapor.',
      'Adet döngüsü takibi: evreye göre iştah, su ve beslenme notları. Öğün, su ve tartı hatırlatmaları; ana ekrana "bugün kalan kalori" widget\'ı.',
      'Google Drive\'a yedek alma / geri yükleme (hiçbir kayıt silinmez), "Sistem (Material You)" renk şeması, yumuşak geçişler ve daha küçük APK.',
    ],
    'en': [
      'Add by typing or voice: just say "1 bowl of lentil soup, 2 slices of bread" (Turkish, English, Arabic; works offline too).',
      'Favourites, frequent foods and my recipes: enter the ingredients of a home-made dish and get the calories per serving. Re-add yesterday\'s meal with one tap.',
      'Personal goal on first start (Mifflin-St Jeor) with a safe minimum. Macro bars on the home page, macro rings, a water chart and weekly / monthly reports in Statistics.',
      'Menstrual cycle tracking with appetite, water and nutrition notes per phase. Meal, water and weigh-in reminders; a "calories left today" home-screen widget.',
      'Backup to / restore from Google Drive (nothing is ever deleted), a "System (Material You)" colour scheme, smoother transitions and a smaller APK.',
    ],
    'ar': [
      'الإضافة بالكتابة أو بالصوت: يكفي أن تقولي «صحن شوربة عدس وشريحتا خبز» (التركية والإنجليزية والعربية؛ ويعمل دون إنترنت أيضاً).',
      'المفضلة والأكثر تناولاً ووصفاتي: أدخلي مكونات طبق منزلي واحصلي على السعرات لكل حصة. أعيدي إضافة وجبة الأمس بلمسة واحدة.',
      'هدف شخصي عند التشغيل الأول (ميفلين-سانت جيور) مع حد أدنى آمن. أشرطة العناصر الغذائية في الصفحة الرئيسية، وحلقاتها ورسم الماء والتقرير الأسبوعي / الشهري في الإحصاءات.',
      'متابعة الدورة الشهرية مع ملاحظات الشهية والماء والتغذية لكل مرحلة. تذكيرات الوجبات والماء والوزن؛ وأداة «السعرات المتبقية اليوم» على الشاشة الرئيسية.',
      'نسخ احتياطي إلى Google Drive واسترجاع منه (لا يُحذف أي سجل)، ونظام ألوان «النظام (Material You)»، وانتقالات أنعم وحجم APK أصغر.',
    ],
  }),
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
