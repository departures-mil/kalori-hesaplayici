import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// v1.0.8: Uygulamaya yöneticinin anahtarı GÖMÜLMEZ — herkes kendi ücretsiz
/// anahtarını girer (yöneticinin yapay zekâ kotası başkalarınca harcanmasın).
/// Derlemedeki --dart-define değerleri bilerek kullanılmıyor.
const kBundledGeminiKey = '';
const kBundledOpenAiKey = '';
const kBundledClaudeKey = '';

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

  int get dailyGoal => customGoal ?? calculatedGoal;

  String get geminiKey {
    final v = _p.getString('geminiKey') ?? '';
    return v.isNotEmpty ? v : kBundledGeminiKey;
  }

  /// Key typed by the user in Settings (may be empty).
  String get manualGeminiKey => _p.getString('geminiKey') ?? '';

  /// Keys to try, in order: the user's own key, then the bundled one.
  List<String> get geminiKeys => [
        for (final k in {manualGeminiKey, kBundledGeminiKey})
          if (k.isNotEmpty) k,
      ];

  void clearKeys() {
    _p.remove('geminiKey');
    _p.remove('openAiKey');
    _p.remove('claudeKey');
    notifyListeners();
  }

  String get openAiKey {
    final v = _p.getString('openAiKey') ?? '';
    return v.isNotEmpty ? v : kBundledOpenAiKey;
  }

  String get claudeKey {
    final v = _p.getString('claudeKey') ?? '';
    return v.isNotEmpty ? v : kBundledClaudeKey;
  }

  void setKeys({String? gemini, String? openAi, String? claude}) {
    if (gemini != null) _p.setString('geminiKey', gemini.trim());
    if (openAi != null) _p.setString('openAiKey', openAi.trim());
    if (claude != null) _p.setString('claudeKey', claude.trim());
    notifyListeners();
  }

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

  int get foodsVersion => _p.getInt('foodsVersion') ?? 0;
  set foodsVersion(int v) => _p.setInt('foodsVersion', v);
}
