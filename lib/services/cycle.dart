/// 1.1.1 — adet döngüsü: kayıtlı başlangıç günlerinden bugünün evresi ve
/// bir sonraki başlangıç tahmini. Yalnızca bilgilendirme amaçlıdır.
class CycleInfo {
  final int day; // döngünün kaçıncı günü (1'den)
  final int length; // ortalama döngü uzunluğu
  final String phase; // menstrual / follicular / ovulation / luteal
  final DateTime nextStart;
  final int daysToNext;
  final bool late; // beklenen gün geçti
  const CycleInfo(this.day, this.length, this.phase, this.nextStart, this.daysToNext, this.late);
}

class Cycle {
  static const phases = ['menstrual', 'follicular', 'ovulation', 'luteal'];

  static DateTime _d(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Takvim günü farkı (yaz saati geçişlerinden etkilenmez).
  static int _between(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  /// Son en çok 6 döngünün ortalaması (21–45 gün arası olanlar), yoksa [fallback].
  static int averageLength(List<DateTime> starts, int fallback) {
    final s = starts.map(_d).toSet().toList()..sort();
    final lens = <int>[];
    for (var i = 1; i < s.length; i++) {
      final l = _between(s[i - 1], s[i]);
      if (l >= 21 && l <= 45) lens.add(l);
    }
    if (lens.isEmpty) return fallback;
    final last = lens.length > 6 ? lens.sublist(lens.length - 6) : lens;
    return (last.reduce((a, b) => a + b) / last.length).round();
  }

  static String phaseFor(int day, int length, int periodLen) {
    final ovu = length - 14; // yumurtlama genelde bir sonraki adetten ~14 gün önce
    if (day <= periodLen) return 'menstrual';
    if (day >= ovu - 1 && day <= ovu + 1) return 'ovulation';
    if (day < ovu - 1) return 'follicular';
    return 'luteal';
  }

  static CycleInfo? compute(List<DateTime> starts, DateTime today,
      {int fallbackLength = 28, int periodLength = 5}) {
    final t = _d(today);
    final past = starts.map(_d).where((d) => !d.isAfter(t)).toSet().toList()..sort();
    if (past.isEmpty) return null;
    final len = averageLength(past, fallbackLength);
    final last = past.last;
    final day = _between(last, t) + 1;
    var next = DateTime(last.year, last.month, last.day + len);
    final late = !next.isAfter(t) && day > len;
    if (late) next = DateTime(t.year, t.month, t.day + 1);
    final eff = day > len ? len : day;
    return CycleInfo(day, len, phaseFor(eff, len, periodLength), next,
        _between(t, next), late);
  }
}
