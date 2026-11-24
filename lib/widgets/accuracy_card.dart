import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/settings.dart';
import '../l10n/strings.dart';
import '../services/food_db.dart';
import '../services/food_model.dart';
import '../services/nutrition_db.dart';
import '../services/portion_learner.dart';
import '../services/update_service.dart' show DownloadProgress;
import 'common.dart';

/// Settings > "Accuracy": plate size, learning from corrections, the offline
/// food model and the nutrition tables.
class AccuracyCard extends StatefulWidget {
  const AccuracyCard({super.key});

  @override
  State<AccuracyCard> createState() => _AccuracyCardState();
}

class _AccuracyCardState extends State<AccuracyCard> {
  final _model = FoodModel.instance;
  bool? _installed;

  @override
  void initState() {
    super.initState();
    _model.addListener(_refresh);
    _refresh();
    NutritionDb.instance.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _model.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final v = await _model.installed;
    if (mounted) setState(() => _installed = v);
  }

  Future<void> _plate(S s) async {
    final st = Settings.instance;
    final c =
        TextEditingController(text: st.plateCm > 0 ? '${st.plateCm}' : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(s['plate_setting']),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '26', suffixText: 'cm'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(s['cancel'])),
          FilledButton(
              onPressed: () => Navigator.pop(d, true), child: Text(s['ok'])),
        ],
      ),
    );
    if (ok != true) return;
    final v = int.tryParse(c.text.trim()) ?? 0;
    st.plateCm = (v >= 10 && v <= 50) ? v : 0;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = Settings.instance;
    final learner = PortionLearner.instance;
    final small = Theme.of(context).textTheme.bodySmall;
    final prog = _model.progress;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // plate size
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.circle_outlined, color: AppColors.rose),
            title: Text(s['plate_setting']),
            subtitle: Text(st.plateCm > 0
                ? '${st.plateCm} cm'
                : s['plate_setting_sub']),
            trailing: Icon(Icons.edit_rounded),
            onTap: () => _plate(s),
          ),
          Divider(),
          // learning
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary:
                Icon(Icons.auto_graph_rounded, color: AppColors.lavender),
            title: Text(s['learn_title']),
            subtitle:
                Text(s.f('learn_sub', {'n': learner.learnedCount})),
            value: learner.enabled,
            activeColor: AppColors.rose,
            onChanged: (v) => setState(() => learner.enabled = v),
          ),
          if (learner.learnedCount > 0)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () async {
                  await learner.reset();
                  if (!context.mounted) return;
                  setState(() {});
                  showSnack(context, s['learn_reset_done']);
                },
                icon: Icon(Icons.restart_alt_rounded),
                label: Text(s['learn_reset']),
              ),
            ),
          Divider(),
          // offline model
          Row(children: [
            Icon(Icons.memory_rounded, color: AppColors.mint),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['model_title'],
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                      _installed == true
                          ? s['model_ready']
                          : s.f('model_sub', {
                              'mb': DownloadProgress.mb(FoodModel.sizeBytes)
                            }),
                      style: small),
                ],
              ),
            ),
            if (prog == null)
              _installed == true
                  ? TextButton(
                      onPressed: () => _model.delete(),
                      child: Text(s['model_delete']))
                  : FilledButton(
                      onPressed: () async {
                        final ok = await _model.download();
                        if (!ok && context.mounted) {
                          showSnack(context,
                              '${s['model_failed']}\n(${_model.error ?? ''})');
                        }
                      },
                      child: Text(s['model_download'])),
          ]),
          if (prog != null) ...[
            SizedBox(height: 10),
            LinearProgressIndicator(
                value: prog.fraction, color: AppColors.rose, minHeight: 6),
            SizedBox(height: 6),
            Text(
                '${(prog.fraction * 100).round()}%  •  '
                '${DownloadProgress.mb(prog.received)} / ${DownloadProgress.mb(prog.total)}  •  '
                '${s['remaining']}: ${DownloadProgress.mb(prog.remaining)}  •  ${prog.speedText}',
                style: small),
          ],
          Divider(),
          // tables
          Row(children: [
            Icon(Icons.menu_book_rounded, color: AppColors.carbs),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['db_title'],
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                      s.f('db_sub', {
                        'a': FoodDb.instance.foods.length,
                        'b': NutritionDb.instance.usda.length,
                      }),
                      style: small),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
