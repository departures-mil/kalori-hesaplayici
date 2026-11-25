import '../data/db.dart';
import '../data/models.dart';
import '../data/settings.dart';
import '../l10n/strings.dart';
import 'native_bridge.dart';

/// 1.1.1 — öğün / su / tartı hatırlatmaları (Android AlarmManager, cihazda).
/// Kurulum her açılışta ve ayar değişince yenilenir. Öğün zaten girildiyse ya da
/// su hedefi tamamlandıysa o günün hatırlatması gösterilmez (widget özeti kullanılır).
class Reminders {
  static Future<void> apply() async {
    final st = Settings.instance;
    final s = S(st.lang);
    final list = <Map<String, Object>>[];
    var id = 100;
    for (final k in Settings.reminderKinds) {
      if (!st.reminderOn(k)) continue;
      final t = st.reminderTime(k).split(':');
      final h = int.tryParse(t.first) ?? 9;
      final m = int.tryParse(t.length > 1 ? t[1] : '0') ?? 0;
      if (k == 'water') {
        for (var hh = h; hh <= 21; hh += st.waterEvery) {
          list.add({
            'id': id++,
            'hour': hh,
            'minute': m,
            'kind': 'water',
            'title': s['rm_water_title'],
            'body': s['rm_water_body'],
          });
        }
        continue;
      }
      list.add({
        'id': id++,
        'hour': h,
        'minute': m,
        'kind': k == 'weigh' ? 'weigh' : 'meal:$k',
        'title': k == 'weigh' ? s['rm_weigh_title'] : s.f('rm_meal_title', {'m': s[k]}),
        'body': k == 'weigh' ? s['rm_weigh_body'] : s['rm_meal_body'],
      });
    }
    await NativeBridge.setReminders(list);
  }

  /// Ana ekran widget'ı + akıllı hatırlatma için bugünün özeti.
  static Future<void> pushToday() async {
    final st = Settings.instance;
    final s = S(st.lang);
    final now = DateTime.now();
    final entries = await AppDb.instance.entriesForDay(now);
    final water = await AppDb.instance.water(now);
    final kcal = entries.fold(0.0, (a, e) => a + e.kcal);
    final goal = st.dailyGoal;
    final left = goal - kcal;
    await NativeBridge.widgetUpdate({
      'day': AppDb.dayKey(now),
      'consumed': kcal.round(),
      'goal': goal,
      'water': water,
      'waterGoal': st.waterGoal,
      'meals': entries.map((e) => e.meal.name).toSet().join(','),
      'title': s['app_name'],
      'leftLabel': left >= 0 ? s['remaining'] : s['over_goal'],
      'left': left.abs().round(),
      'kcal': s['kcal'],
      'glasses': s['glasses'],
      'rtl': st.lang == 'ar',
      // gün değişince widget kendi başına sıfırlar (bu metinlerle)
      'emptyLeftLabel': s['remaining'],
    });
  }

  static MealType mealForNow() {
    final h = DateTime.now().hour;
    if (h < 11) return MealType.breakfast;
    if (h < 15) return MealType.lunch;
    if (h < 18) return MealType.snack;
    return MealType.dinner;
  }
}
