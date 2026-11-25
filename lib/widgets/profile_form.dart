import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/settings.dart';
import '../l10n/strings.dart';

/// 1.1.1 — kişisel hedef: yaş, boy, kilo, hareket, amaç, özel durum →
/// Mifflin-St Jeor ile günlük ihtiyaç (canlı hesap). İlk açılış rehberinde ve
/// ana ekrandaki "hedefini kişiselleştir" penceresinde kullanılır.
class ProfileForm extends StatefulWidget {
  /// Koyu degrade üzerinde (rehber) beyaz yazı.
  final bool onGradient;
  const ProfileForm({super.key, this.onGradient = false});

  @override
  State<ProfileForm> createState() => ProfileFormState();
}

class ProfileFormState extends State<ProfileForm> {
  final st = Settings.instance;
  late final _age = TextEditingController(text: '${st.age}');
  late final _height = TextEditingController(text: st.height.toStringAsFixed(0));
  late final _weight = TextEditingController(text: st.weight.toStringAsFixed(1));
  late Activity _act = st.activity;
  late Goal _goal = st.goal;
  late Special _special = st.special;

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  int? get _a => int.tryParse(_age.text.trim());
  double? get _h => double.tryParse(_height.text.replaceAll(',', '.').trim());
  double? get _w => double.tryParse(_weight.text.replaceAll(',', '.').trim());

  /// Formdaki değerlerle (henüz kaydetmeden) hesap.
  int get preview {
    final a = (_a ?? st.age).clamp(14, 100);
    final h = (_h ?? st.height).clamp(120.0, 220.0);
    final w = (_w ?? st.weight).clamp(30.0, 250.0);
    final bmr = 10 * w + 6.25 * h - 5 * a - 161;
    const mult = [1.2, 1.375, 1.55, 1.725];
    var t = bmr * mult[_act.index];
    if (_goal == Goal.lose) t -= 400;
    if (_goal == Goal.gain) t += 300;
    if (_special == Special.pregnant) t += 300;
    if (_special == Special.breastfeeding) t += 450;
    final floor = _special == Special.none ? 1200 : 1800;
    return t.clamp(floor.toDouble(), 4000).round();
  }

  /// Formu kaydeder; geçersiz alan varsa false.
  bool save() {
    final a = _a, h = _h, w = _w;
    if (a == null || a < 14 || a > 100 || h == null || h < 120 || h > 220 || w == null || w < 30 || w > 250) {
      return false;
    }
    st.setProfile(age: a, height: h, weight: w, activity: _act, goal: _goal, special: _special);
    st.profileSet = true;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final fg = widget.onGradient ? Colors.white : AppColors.ink;
    InputDecoration deco(String l, [String? suffix]) => InputDecoration(labelText: l, suffixText: suffix, isDense: true);
    Widget num(TextEditingController c, String l, [String? suffix]) => TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: deco(l, suffix),
          onChanged: (_) => setState(() {}),
        );
    Widget drop<T>(String l, T v, List<T> vals, String Function(T) name, void Function(T) on) =>
        DropdownButtonFormField<T>(
          initialValue: v,
          isExpanded: true,
          decoration: deco(l),
          items: [for (final x in vals) DropdownMenuItem(value: x, child: Text(name(x), overflow: TextOverflow.ellipsis))],
          onChanged: (x) {
            if (x != null) setState(() => on(x));
          },
        );
    final form = Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(child: num(_age, s['age'])),
        const SizedBox(width: 8),
        Expanded(child: num(_height, s['height_cm'], 'cm')),
        const SizedBox(width: 8),
        Expanded(child: num(_weight, s['weight_kg'], 'kg')),
      ]),
      const SizedBox(height: 10),
      drop<Activity>(s['activity'], _act, Activity.values, (a) => s['act_${a.name}'], (v) => _act = v),
      const SizedBox(height: 10),
      drop<Goal>(s['goal'], _goal, Goal.values, (g) => s['goal_${g.name}'], (v) => _goal = v),
      const SizedBox(height: 10),
      drop<Special>(s['special'], _special, Special.values, (g) => s['special_${g.name}'], (v) => _special = v),
    ]);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)),
        child: form,
      ),
      const SizedBox(height: 14),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: Text(
          '${s['calculated_goal']}: $preview ${s['kcal']}',
          key: ValueKey(preview),
          textAlign: TextAlign.center,
          style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: 4),
      Text(s['pf_formula'],
          textAlign: TextAlign.center,
          style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 12)),
    ]);
  }
}
