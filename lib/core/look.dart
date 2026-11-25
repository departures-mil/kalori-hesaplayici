import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/native_bridge.dart';
import 'fc_tokens.dart';

/// Ortak çekirdek FC.look'un Flutter karşılığı: renk şeması (falcon varsayılan,
/// klasik = eski görünüm, …), koyu / açık / otomatik mod ve yazı boyutu.
/// Seçimler bu cihazda saklanır (SharedPreferences: fc.scheme, fc.theme, fc.fontScale).
class FcLook extends ChangeNotifier with WidgetsBindingObserver {
  FcLook._();
  static final FcLook instance = FcLook._();

  static const double minScale = 0.85, maxScale = 1.4, step = 0.05;
  static const themes = ['dark', 'light', 'auto'];

  SharedPreferences? _p;
  Brightness _platform = Brightness.dark;
  FcPalette _palette = FcPalette('falcon', true);

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    final b = WidgetsFlutterBinding.ensureInitialized();
    _platform = b.platformDispatcher.platformBrightness;
    b.addObserver(this);
    _rebuild();
  }

  /// Testler için: kalıcı depo olmadan belirli bir görünüm.
  @visibleForTesting
  void debugSet({String? scheme, String? theme, double? scale}) {
    _dbgScheme = scheme ?? _dbgScheme;
    _dbgTheme = theme ?? _dbgTheme;
    _dbgScale = scale ?? _dbgScale;
    _rebuild();
    notifyListeners();
  }

  String? _dbgScheme, _dbgTheme;
  double? _dbgScale;

  /// 1.1.1: Android 12+ duvar kâğıdı renkleri (Material You). Yoksa null.
  static Map<String, int>? dynamicArgb;
  static const systemScheme = 'sistem';
  bool get hasDynamic => dynamicArgb != null;

  /// Şemalar: ortak çekirdeğin 8 şeması + (destekleniyorsa) "Sistem".
  List<String> get schemeIds => [if (hasDynamic) systemScheme, ...kFcSchemeIds];

  Future<void> loadDynamic() async {
    final m = await NativeBridge.dynamicColors();
    if (m == null || !m.containsKey('a1_600')) return;
    dynamicArgb = m;
    _changed();
  }

  String get scheme {
    final s = _dbgScheme ?? _p?.getString('fc.scheme');
    if (s == systemScheme && hasDynamic) return s!;
    return kFcSchemeIds.contains(s) ? s! : 'falcon';
  }

  String get theme {
    final t = _dbgTheme ?? _p?.getString('fc.theme');
    return themes.contains(t) ? t! : 'dark';
  }

  bool get dark => theme == 'auto' ? _platform == Brightness.dark : theme == 'dark';

  double get scale => clampScale(_dbgScale ?? _p?.getDouble('fc.fontScale') ?? 1.0);

  static double clampScale(double x) =>
      ((x * 100).round() / 100).clamp(minScale, maxScale).toDouble();

  FcPalette get palette => _palette;

  void setScheme(String id) {
    if (!kFcSchemeIds.contains(id) && !(id == systemScheme && hasDynamic)) return;
    _p?.setString('fc.scheme', id);
    _dbgScheme = null;
    _changed();
  }

  void setTheme(String t) {
    if (!themes.contains(t)) return;
    _p?.setString('fc.theme', t);
    _dbgTheme = null;
    _changed();
  }

  /// Üst çubuktaki tema düğmesi: koyu ↔ açık.
  void toggle() => setTheme(dark ? 'light' : 'dark');

  void setScale(double x) {
    _p?.setDouble('fc.fontScale', clampScale(x));
    _dbgScale = null;
    _changed();
  }

  void bump(int dir) => setScale(scale + dir * step);

  static String schemeLabel(String id, String lang) =>
      kFcSchemeLabels[id]?[lang] ?? kFcSchemeLabels[id]?['en'] ?? id;

  void _rebuild() => _palette = FcPalette(scheme, dark);

  void _changed() {
    _rebuild();
    notifyListeners();
  }

  @override
  void didChangePlatformBrightness() {
    _platform = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (theme == 'auto') _changed();
  }
}

/// Bir şemanın (koyu ya da açık) renkleri.
class FcPalette {
  final String scheme;
  final bool dark;
  final Map<String, Color> _t;
  FcPalette(this.scheme, this.dark) : _t = _tokens(scheme, dark);

  static Map<String, Color> _tokens(String scheme, bool dark) {
    final mode = dark ? 'dark' : 'light';
    final d = FcLook.dynamicArgb;
    if (scheme != FcLook.systemScheme || d == null) return kFcTokens[scheme]![mode]!;
    // "Sistem": falcon tabanı + duvar kâğıdından gelen vurgu renkleri
    Color c(String k, int fb) => Color(d[k] ?? fb);
    final base = Map<String, Color>.from(kFcTokens['falcon']![mode]!);
    final accent = dark ? c('a1_200', 0xFFA8C7FA) : c('a1_600', 0xFF3367D6);
    final accent2 = dark ? c('a3_200', 0xFFD7BAFF) : c('a3_600', 0xFF7E57C2);
    base.addAll({
      'accent': accent,
      'accent-2': accent2,
      'on-accent': dark ? c('a1_800', 0xFF062E6F) : const Color(0xFFFFFFFF),
      'primary-1': c('a1_600', 0xFF3367D6),
      'primary-2': c('a3_600', 0xFF7E57C2),
      'focus': accent,
      'active-1': accent.withValues(alpha: 0.16),
      'accent-soft': accent.withValues(alpha: 0.14),
      'accent-line': accent.withValues(alpha: 0.4),
      'bg': dark ? c('n1_900', 0xFF1B1B1F) : c('n1_10', 0xFFFDFBFF),
      'panel-solid': dark ? c('n1_800', 0xFF2F3033) : c('n1_50', 0xFFF1F0F4),
    });
    return base;
  }

  Color operator [](String token) => _t[token] ?? const Color(0xFFFF00FF);

  bool get klasikLight => scheme == 'klasik' && !dark;

  Color get bg => this['bg'];
  Color get panel => this['panel-solid'];
  Color get panelHover => this['panel-hover'];
  Color get text => this['text'];
  Color get muted => this['muted'];
  Color get accent => this['accent'];
  Color get accent2 => this['accent-2'];
  Color get onAccent => this['on-accent'];
  Color get border => this['border'];
  Color get danger => this['danger'];
  Color get warn => this['warn'];
  Color get ok => this['ok'];

  Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  /// Uygulamanın eski adlandırmasıyla (AppColors) renkler.
  Color get rose => accent;
  Color get roseSoft => klasikLight ? const Color(0xFFF8A5C2) : _mix(accent, panel, 0.55);
  Color get lavender => accent2;
  Color get lavenderSoft => klasikLight ? const Color(0xFFD9CCF5) : _mix(accent2, panel, dark ? 0.6 : 0.72);
  Color get peach => klasikLight ? const Color(0xFFFFC2A8) : _mix(warn, panel, 0.3);
  Color get mint => klasikLight ? const Color(0xFF8FD9C1) : _mix(ok, panel, 0.25);
  Color get carbs => klasikLight ? const Color(0xFFFFB457) : warn;

  /// Degrade kartlar (üzerinde beyaz yazı). Yüksek kontrast koyu modda sarı yerine siyah.
  List<Color> get gradient {
    if (scheme == 'yuksek-kontrast' && dark) return const [Color(0xFF000000), Color(0xFF1F1F1F)];
    if (klasikLight) return const [Color(0xFFE75480), Color(0xFF9B7EDE)];
    return [this['primary-1'], this['primary-2']];
  }
}
