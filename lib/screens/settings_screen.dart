import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/settings.dart';
import '../l10n/strings.dart';
import '../services/update_service.dart';
import '../widgets/common.dart';
import '../widgets/window_controls.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final st = Settings.instance;
  late final _age = TextEditingController(text: '${st.age}');
  late final _height = TextEditingController(text: st.height.toStringAsFixed(0));
  late final _weight = TextEditingController(text: st.weight.toStringAsFixed(1));
  late final _custom =
      TextEditingController(text: st.customGoal?.toString() ?? '');
  late final _gemini = TextEditingController();
  late final _openai = TextEditingController();
  late final _claude = TextEditingController();
  String _version = '';

  @override
  void initState() {
    super.initState();
    UpdateService.currentVersion().then((v) {
      if (mounted) setState(() => _version = v);
    });
  }

  void _saveProfile() {
    st.setProfile(
      age: int.tryParse(_age.text),
      height: double.tryParse(_height.text.replaceAll(',', '.')),
      weight: double.tryParse(_weight.text.replaceAll(',', '.')),
      customGoal: int.tryParse(_custom.text) ?? 0,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        _section(s['language']),
        SoftCard(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              for (final l in const [
                ('tr', 'turkish'),
                ('en', 'english'),
                ('ar', 'arabic')
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: ChoiceChip(
                      label: Center(child: Text(s[l.$2])),
                      selected: st.lang == l.$1,
                      selectedColor: AppColors.roseSoft,
                      onSelected: (_) => st.lang = l.$1,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _section(s['profile']),
        SoftCard(
          child: Column(
            children: [
              Row(children: [
                Expanded(child: _num(_age, s['age'])),
                const SizedBox(width: 10),
                Expanded(child: _num(_height, s['height_cm'])),
                const SizedBox(width: 10),
                Expanded(child: _num(_weight, s['weight_kg'])),
              ]),
              const SizedBox(height: 12),
              _drop<Activity>(
                  s['activity'],
                  st.activity,
                  Activity.values,
                  (a) => s['act_${a.name}'],
                  (v) => st.setProfile(activity: v)),
              const SizedBox(height: 10),
              _drop<Goal>(s['goal'], st.goal, Goal.values,
                  (g) => s['goal_${g.name}'], (v) => st.setProfile(goal: v)),
              const SizedBox(height: 10),
              _drop<Special>(
                  s['special'],
                  st.special,
                  Special.values,
                  (g) => s['special_${g.name}'],
                  (v) => st.setProfile(special: v)),
              const SizedBox(height: 12),
              _num(_custom, s['custom_goal']),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                        '${s['calculated_goal']}: ${st.calculatedGoal} ${s['kcal']}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  FilledButton(
                    onPressed: _saveProfile,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(90, 44)),
                    child: Text(s['save']),
                  ),
                ],
              ),
            ],
          ),
        ),
        _section(s['api_keys']),
        SoftCard(
          child: Column(
            children: [
              Text(s['key_hint'],
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 10),
              TextField(
                  controller: _gemini,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: s['gemini_key'],
                      hintText: st.geminiKey.isNotEmpty ? '••••••••' : '')),
              const SizedBox(height: 10),
              TextField(
                  controller: _openai,
                  obscureText: true,
                  decoration: InputDecoration(labelText: s['openai_key'])),
              const SizedBox(height: 10),
              TextField(
                  controller: _claude,
                  obscureText: true,
                  decoration: InputDecoration(labelText: s['claude_key'])),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  onPressed: () {
                    st.setKeys(
                      gemini: _gemini.text.isEmpty ? null : _gemini.text,
                      openAi: _openai.text.isEmpty ? null : _openai.text,
                      claude: _claude.text.isEmpty ? null : _claude.text,
                    );
                    showSnack(context, s['saved']);
                  },
                  style:
                      FilledButton.styleFrom(minimumSize: const Size(90, 44)),
                  child: Text(s['save']),
                ),
              ),
            ],
          ),
        ),
        _section(s['update']),
        SoftCard(
          child: Row(
            children: [
              Expanded(child: Text('${s['version']}: $_version')),
              FilledButton.icon(
                onPressed: () => showUpdateDialog(context),
                style:
                    FilledButton.styleFrom(minimumSize: const Size(120, 44)),
                icon: const Icon(Icons.system_update_alt_rounded, size: 18),
                label: Text(s['update']),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(t, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _num(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, isDense: true),
      );

  Widget _drop<T>(String label, T value, List<T> values,
          String Function(T) name, void Function(T) onChanged) =>
      DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: values
            .map((v) => DropdownMenuItem(value: v, child: Text(name(v))))
            .toList(),
        onChanged: (v) {
          if (v != null) {
            onChanged(v);
            setState(() {});
          }
        },
      );
}
