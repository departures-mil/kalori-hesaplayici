import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Uygulamaya HİÇBİR yapay zekâ anahtarı gömülmez (v1.1.0: derlemeden de
// kaldırıldı). Her kullanıcı kendi anahtarını ilk açılışta ya da Ayarlar'da girer.

const kGithubOwner = 'departures-mil';
const kGithubRepo = 'kalori-hesaplayici';

enum Activity { sedentary, light, moderate, active }

enum Goal { lose, keep, gain }

enum Special { none, pregnant, breastfeeding }

class Settings extends ChangeNotifier {
  Settings._();
  static final Settings instance = Settings._();
  late SharedPreferences _p;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  String get lang => _p.getString('lang') ?? 'tr';
  set lang(String v) {
    _p.setString('lang', v);
    notifyListeners();
  }

  int get age => _p.getInt('age') ?? 30;
  double get height => _p.getDouble('height') ?? 165;
  double get weight => _p.getDouble('weight') ?? 65;
  Activity get activity => Activity.values[_p.getInt('activity') ?? 1];
  Goal get goal => Goal.values[_p.getInt('goal') ?? 1];
  Special get special => Special.values[_p.getInt('special') ?? 0];
  int? get customGoal {
    final v = _p.getInt('customGoal');
    return (v == null || v <= 0) ? null : v;
  }

  void setProfile({
    int? age,
    double? height,
    double? weight,
    Activity? activity,
    Goal? goal,
    Special? special,
    int? customGoal,
  }) {
    if (age != null) _p.setInt('age', age);
    if (height != null) _p.setDouble('height', height);
    if (weight != null) _p.setDouble('weight', weight);
    if (activity != null) _p.setInt('activity', activity.index);
    if (goal != null) _p.setInt('goal', goal.index);
    if (special != null) _p.setInt('special', special.index);
    if (customGoal != null) _p.setInt('customGoal', customGoal);
    notifyListeners();
  }

  /// Mifflin-St Jeor for women.
  int get calculatedGoal {
    final bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    const mult = [1.2, 1.375, 1.55, 1.725];
    var tdee = bmr * mult[activity.index];
    switch (goal) {
      case Goal.lose:
        tdee -= 400;
      case Goal.gain:
        tdee += 300;
      case Goal.keep:
        break;
    }
    switch (special) {
      case Special.pregnant:
        tdee += 300;
      case Special.breastfeeding:
        tdee += 450;
      case Special.none:
        break;
    }
    return tdee.clamp(1200, 4000).round();
  }

  /// Güvenli alt sınır: elle girilen hedef de 1200 kcal'nin altına inemez
  /// (hamilelik / emzirmede 1800).
  int get minSafeGoal => special == Special.none ? 1200 : 1800;
  int get dailyGoal {
    final c = customGoal;
    if (c == null) return calculatedGoal < minSafeGoal ? minSafeGoal : calculatedGoal;
    return c < minSafeGoal ? minSafeGoal : c;
  }

  /// Kullanıcının kendi Gemini anahtarı (boş olabilir).
  String get geminiKey => _p.getString('geminiKey') ?? '';

  /// Key typed by the user in Settings (may be empty).
  String get manualGeminiKey => _p.getString('geminiKey') ?? '';

  /// Denenecek Gemini anahtarları: yalnızca kullanıcının kendi anahtarı.
  List<String> get geminiKeys => [if (geminiKey.isNotEmpty) geminiKey];

  void clearKeys() {
    _p.remove('geminiKey');
    _p.remove('openAiKey');
    _p.remove('claudeKey');
    notifyListeners();
  }

  String get openAiKey => _p.getString('openAiKey') ?? '';

  String get claudeKey => _p.getString('claudeKey') ?? '';

  void setKeys({String? gemini, String? openAi, String? claude}) {
    if (gemini != null) _p.setString('geminiKey', gemini.trim());
    if (openAi != null) _p.setString('openAiKey', openAi.trim());
    if (claude != null) _p.setString('claudeKey', claude.trim());
    notifyListeners();
  }

  /// "Neler yeni" en son hangi sürüm için gösterildi.
  String? get lastSeenVersion => _p.getString('fc.lastSeenVersion');
  set lastSeenVersion(String? v) =>
      v == null ? _p.remove('fc.lastSeenVersion') : _p.setString('fc.lastSeenVersion', v);

  bool get welcomed => _p.getBool('welcomed') ?? false;
  set welcomed(bool v) => _p.setBool('welcomed', v);

  /// v1.0.11: the user's own plate diameter in cm (0 = not set).
  int get plateCm => _p.getInt('plateCm') ?? 0;
  set plateCm(int v) {
    _p.setInt('plateCm', v);
    notifyListeners();
  }

  /// Last size reference chosen in the "what's on the plate" sheet.
  String get lastRef => _p.getString('lastRef') ?? 'none';
  set lastRef(String v) => _p.setString('lastRef', v);

  // ---------------- 1.1.1 ----------------

  /// Profil (ilk açılış rehberinde ya da Ayarlar'da) en az bir kez kaydedildi mi.
  bool get profileSet => _p.getBool('profileSet') ?? false;
  set profileSet(bool v) {
    _p.setBool('profileSet', v);
    notifyListeners();
  }

  /// Adet döngüsü takibi.
  bool get cycleOn => _p.getBool('cycleOn') ?? false;
  set cycleOn(bool v) {
    _p.setBool('cycleOn', v);
    notifyListeners();
  }

  int get cycleLen => _p.getInt('cycleLen') ?? 28;
  set cycleLen(int v) {
    _p.setInt('cycleLen', v.clamp(21, 45));
    notifyListeners();
  }

  int get periodLen => _p.getInt('periodLen') ?? 5;
  set periodLen(int v) {
    _p.setInt('periodLen', v.clamp(2, 10));
    notifyListeners();
  }

  /// Günlük su hedefi (bardak, 200 ml). 0 = kiloya göre (35 ml/kg).
  int get waterGoalRaw => _p.getInt('waterGoal') ?? 0;
  int get waterGoal {
    final r = waterGoalRaw;
    if (r > 0) return r;
    var ml = weight * 35;
    if (special == Special.breastfeeding) ml += 700;
    if (special == Special.pregnant) ml += 300;
    return (ml / 200).round().clamp(6, 16);
  }

  set waterGoal(int v) {
    _p.setInt('waterGoal', v.clamp(0, 30));
    notifyListeners();
  }

  /// Makro dağılımı (% kalori): protein / karbonhidrat / yağ.
  static const macroSplit = (p: 0.20, c: 0.50, f: 0.30);
  double get proteinTarget => dailyGoal * macroSplit.p / 4;
  double get carbsTarget => dailyGoal * macroSplit.c / 4;
  double get fatTarget => dailyGoal * macroSplit.f / 9;

  /// Hatırlatmalar: tür → "SS:DD" (boş = kapalı). JSON yerine düz anahtarlar.
  static const reminderKinds = ['breakfast', 'lunch', 'dinner', 'snack', 'water', 'weigh'];
  static const reminderDefaults = {
    'breakfast': '08:30',
    'lunch': '12:30',
    'dinner': '19:00',
    'snack': '16:00',
    'water': '10:00',
    'weigh': '07:30',
  };
  bool reminderOn(String k) => _p.getBool('rem.$k') ?? false;
  String reminderTime(String k) => _p.getString('rem.$k.t') ?? reminderDefaults[k]!;
  void setReminder(String k, {bool? on, String? time}) {
    if (on != null) _p.setBool('rem.$k', on);
    if (time != null) _p.setString('rem.$k.t', time);
    notifyListeners();
  }

  /// Su hatırlatması kaç saatte bir (başlangıç saatinden 21:00'e kadar).
  int get waterEvery => _p.getInt('rem.water.every') ?? 2;
  set waterEvery(int v) {
    _p.setInt('rem.water.every', v.clamp(1, 4));
    notifyListeners();
  }

  /// Son yedek alma zamanı (ms, 0 = hiç).
  int get lastBackup => _p.getInt('lastBackup') ?? 0;
  set lastBackup(int v) => _p.setInt('lastBackup', v);

  int get foodsVersion => _p.getInt('foodsVersion') ?? 0;
  set foodsVersion(int v) => _p.setInt('foodsVersion', v);
}
