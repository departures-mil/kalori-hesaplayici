import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_info.dart';
import '../core/theme.dart';
import '../data/db.dart';
import '../data/settings.dart';
import '../l10n/strings.dart';
import '../screens/cycle_screen.dart';
import '../services/native_bridge.dart';
import '../services/reminders.dart';
import 'common.dart';

/// 1.1.1 — Ayarlar → Hatırlatmalar (öğün, su, tartı).
class ReminderCard extends StatefulWidget {
  const ReminderCard({super.key});

  @override
  State<ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<ReminderCard> {
  final st = Settings.instance;

  static const _icons = {
    'breakfast': Icons.free_breakfast_rounded,
    'lunch': Icons.lunch_dining_rounded,
    'dinner': Icons.dinner_dining_rounded,
    'snack': Icons.cookie_rounded,
    'water': Icons.water_drop_rounded,
    'weigh': Icons.monitor_weight_rounded,
  };

  Future<void> _toggle(String k, bool v) async {
    if (v) {
      final ok = await NativeBridge.notifPermission();
      if (!ok && mounted) showSnack(context, S.of(context)['rm_perm']);
    }
    st.setReminder(k, on: v);
    setState(() {});
    await Reminders.apply();
  }

  Future<void> _time(String k) async {
    final p = st.reminderTime(k).split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(p.first) ?? 9, minute: int.tryParse(p.last) ?? 0),
    );
    if (t == null) return;
    st.setReminder(k,
        time: '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}', on: true);
    setState(() {});
    await Reminders.apply();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Text(s['rm_desc'], style: Theme.of(context).textTheme.bodySmall),
        ),
        for (final k in Settings.reminderKinds)
          ListTile(
            contentPadding: const EdgeInsetsDirectional.only(start: 8, end: 0),
            leading: Icon(_icons[k], color: st.reminderOn(k) ? AppColors.rose : AppColors.inkSoft),
            title: Text(k == 'water' ? s['rm_water'] : (k == 'weigh' ? s['rm_weigh'] : s[k])),
            subtitle: Text(k == 'water'
                ? s.f('rm_water_sub', {'t': st.reminderTime(k), 'n': st.waterEvery})
                : st.reminderTime(k)),
            onTap: () => _time(k),
            trailing: Switch(value: st.reminderOn(k), onChanged: (v) => _toggle(k, v)),
          ),
        if (st.reminderOn('water'))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              Expanded(child: Text(s['rm_every'])),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [for (final n in [1, 2, 3]) ButtonSegment(value: n, label: Text('$n s'))],
                selected: {st.waterEvery},
                onSelectionChanged: (v) async {
                  st.waterEvery = v.first;
                  setState(() {});
                  await Reminders.apply();
                },
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
          child: Row(children: [
            Icon(Icons.widgets_rounded, size: 18, color: AppColors.lavender),
            const SizedBox(width: 8),
            Expanded(child: Text(s['wg_hint'], style: Theme.of(context).textTheme.bodySmall)),
          ]),
        ),
      ]),
    );
  }
}

/// 1.1.1 — Ayarlar → Su hedefi ve adet döngüsü takibi.
class HealthCard extends StatefulWidget {
  const HealthCard({super.key});

  @override
  State<HealthCard> createState() => _HealthCardState();
}

class _HealthCardState extends State<HealthCard> {
  final st = Settings.instance;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final auto = st.waterGoalRaw == 0;
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.water_drop_rounded, color: AppColors.lavender),
          const SizedBox(width: 8),
          Expanded(child: Text(s.f('wt_goal', {'n': st.waterGoal}), style: const TextStyle(fontWeight: FontWeight.w600))),
          IconButton(
              tooltip: s['wt_less'],
              onPressed: st.waterGoal <= 4 ? null : () => setState(() => st.waterGoal = st.waterGoal - 1),
              icon: const Icon(Icons.remove_circle_outline_rounded)),
          IconButton(
              tooltip: s['wt_more'],
              onPressed: () => setState(() => st.waterGoal = st.waterGoal + 1),
              icon: const Icon(Icons.add_circle_outline_rounded)),
        ]),
        Row(children: [
          Expanded(
              child: Text(auto ? s['wt_auto'] : s['wt_manual'], style: Theme.of(context).textTheme.bodySmall)),
          if (!auto)
            TextButton(onPressed: () => setState(() => st.waterGoal = 0), child: Text(s['font_reset'])),
        ]),
        const Divider(height: 22),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(Icons.favorite_rounded, color: AppColors.rose),
          title: Text(s['cy_title']),
          subtitle: Text(st.special == Special.none ? s['cy_switch_sub'] : s['cy_paused']),
          value: st.cycleOn,
          onChanged: (v) => setState(() => st.cycleOn = v),
        ),
        if (st.cycleOn)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CycleScreen())),
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text(s['cy_open']),
            ),
          ),
      ]),
    );
  }
}

/// 1.1.1 — Ayarlar → Yedekleme: herkes kendi Google Drive'ına (sistem kaydet
/// penceresinde Drive seçilir) ya da telefona yedek alır; geri yüklemede hiçbir
/// kayıt silinmez, aynı kayıtta yeni olan kalır (Wi‑Fi eşitlemesiyle aynı kural).
class BackupCard extends StatefulWidget {
  const BackupCard({super.key});

  @override
  State<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<BackupCard> {
  bool _busy = false;

  Future<void> _export() async {
    final s = S.of(context);
    setState(() => _busy = true);
    try {
      final data = await AppDb.instance.exportAll();
      data['backup'] = {'version': kAppVersion, 'time': DateTime.now().toIso8601String()};
      final name = 'kalori-yedek-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
      final ok = await NativeBridge.saveDocument(name, jsonEncode(data));
      if (!mounted) return;
      if (ok) {
        Settings.instance.lastBackup = DateTime.now().millisecondsSinceEpoch;
        showSnack(context, s['bk_saved']);
      } else {
        showSnack(context, s['bk_cancel']);
      }
    } catch (_) {
      if (mounted) showSnack(context, s['bk_error']);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final s = S.of(context);
    setState(() => _busy = true);
    try {
      final raw = await NativeBridge.openDocument();
      if (raw == null) {
        if (mounted) showSnack(context, s['bk_cancel']);
        return;
      }
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final r = await AppDb.instance.mergeAll(j);
      if (!mounted) return;
      showSnack(context, s.f('lan_merged', {'a': r['added'] ?? 0, 'u': r['updated'] ?? 0}));
    } catch (_) {
      if (mounted) showSnack(context, s['bk_bad']);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final last = Settings.instance.lastBackup;
    final lang = Settings.instance.lang;
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(s['bk_desc'], style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Text(
            last == 0
                ? s['bk_never']
                : s.f('bk_last', {'d': DateFormat.yMMMd(lang).add_Hm().format(DateTime.fromMillisecondsSinceEpoch(last))}),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.cloud_upload_rounded, size: 18),
              label: Text(s['bk_export']),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _import,
              icon: const Icon(Icons.cloud_download_rounded, size: 18),
              label: Text(s['bk_import']),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Text(s['bk_auto'], style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
