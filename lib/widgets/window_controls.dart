import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_info.dart';
import '../core/look.dart';
import '../core/theme.dart';
import '../data/news.dart';
import '../data/settings.dart';
import '../l10n/strings.dart';
import '../screens/lan_sync_screen.dart';
import '../services/sync_service.dart';
import '../services/update_service.dart';
import 'common.dart';

const _channel = MethodChannel('kalori/window');

/// Sağ üst sıra (ortak çekirdek): Eşitle (Wi‑Fi alt seçenek), Güncelle, tema, dil | Küçült, Kapat.
/// Telefonda Orta / Tam ekran düğmeleri yoktur (uygulama zaten tam ekran).
class WindowControls extends StatefulWidget {
  const WindowControls({super.key});

  /// Açılıştaki tek sessiz denetimin sonucu (üst çubuktaki nokta).
  static final ValueNotifier<UpdatePlan?> available = ValueNotifier(null);

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> {
  bool _syncing = false;

  Future<void> _sync() async {
    final s = S.of(context);
    setState(() => _syncing = true);
    try {
      await SyncService.sync();
      if (mounted) showSnack(context, s['sync_done']);
    } catch (_) {
      if (mounted) showSnack(context, s['sync_failed']);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// Eşitle: önce normal (online), altında ikinci seçenek Wi-Fi (internetsiz).
  Future<void> _syncMenu() async {
    final s = S.of(context);
    final c = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (b) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.cloud_sync_rounded, color: AppColors.rose),
            title: Text(s['sync_online']),
            subtitle: Text(s['sync_online_hint']),
            onTap: () => Navigator.pop(b, 1),
          ),
          ListTile(
            leading: Icon(Icons.wifi_rounded, color: AppColors.lavender),
            title: Text(s['lan_title']),
            subtitle: Text(s['lan_menu_hint']),
            onTap: () => Navigator.pop(b, 2),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted) return;
    if (c == 1) await _sync();
    if (c == 2) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const LanSyncScreen()));
    }
  }

  Future<void> _lang() async {
    final s = S.of(context);
    final st = Settings.instance;
    final l = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (b) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final x in const [('tr', 'turkish'), ('en', 'english'), ('ar', 'arabic')])
            ListTile(
              leading: Icon(st.lang == x.$1 ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: AppColors.rose),
              title: Text(s[x.$2]),
              onTap: () => Navigator.pop(b, x.$1),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (l != null) st.lang = l;
  }

  Future<void> _minimize() async {
    try {
      await _channel.invokeMethod('minimize');
    } catch (_) {}
  }

  Future<void> _close() async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s['exit_confirm']),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s['no'])),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
              onPressed: () => Navigator.pop(c, true),
              child: Text(s['yes'])),
        ],
      ),
    );
    if (ok == true) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final look = FcLook.instance;
    return ValueListenableBuilder<UpdatePlan?>(
      valueListenable: WindowControls.available,
      builder: (context, plan, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(
            icon: Icons.sync_rounded,
            tip: s['sync'],
            busy: _syncing,
            onTap: _syncing ? null : _syncMenu,
          ),
          _btn(
            icon: Icons.system_update_alt_rounded,
            tip: s['update'],
            badge: plan != null,
            onTap: () => showUpdateDialog(context),
          ),
          _btn(
            icon: look.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            tip: s['theme_toggle'],
            onTap: look.toggle,
          ),
          _btn(icon: Icons.translate_rounded, tip: s['language_btn'], onTap: _lang),
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: FcLook.instance.palette.border,
          ),
          _btn(icon: Icons.remove_rounded, tip: s['minimize'], onTap: _minimize),
          _btn(icon: Icons.close_rounded, tip: s['close'], onTap: _close),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _btn({
    required IconData icon,
    required String tip,
    VoidCallback? onTap,
    bool badge = false,
    bool busy = false,
  }) =>
      Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                busy
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(icon, size: 21, color: AppColors.ink, semanticLabel: tip),
                if (badge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(color: AppColors.rose, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

/// Açılışta bir kez sessizce denetler; yeni sürüm varsa ekranda pencere açar.
Future<void> startupUpdateCheck(BuildContext context) async {
  try {
    final plan = await UpdateService.check();
    WindowControls.available.value = plan;
    if (plan != null && context.mounted) await showUpdateDialog(context, plan: plan);
  } catch (_) {}
}

/// Güncelleme: denetle → (onay) → indir (yüzde, MB, kalan, hız; yamada "yalnızca değişen
/// kısımlar") → SHA-256 doğrula → kur.
Future<void> showUpdateDialog(BuildContext context, {UpdatePlan? plan}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(plan: plan),
  );
}

enum _Stage { checking, none, ready, downloading, verifying, install, failed }

class _UpdateDialog extends StatefulWidget {
  final UpdatePlan? plan;
  const _UpdateDialog({this.plan});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _Stage _stage = _Stage.checking;
  UpdatePlan? _plan;
  UpdateProgress? _p;
  String _error = '';
  bool _fellBack = false;
  File? _apk;

  @override
  void initState() {
    super.initState();
    if (widget.plan != null) {
      _plan = widget.plan;
      _stage = _Stage.ready;
    } else {
      _check();
    }
  }

  Future<void> _check() async {
    setState(() => _stage = _Stage.checking);
    try {
      final plan = await UpdateService.check();
      WindowControls.available.value = plan;
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _stage = plan == null ? _Stage.none : _Stage.ready;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = _Stage.failed;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _go() async {
    final plan = _plan!;
    setState(() => _stage = _Stage.downloading);
    try {
      final f = await UpdateService.obtain(
        plan,
        (p) {
          if (mounted) setState(() => _p = p);
        },
        onFallback: (_) {
          if (mounted) setState(() => _fellBack = true);
        },
        onVerifying: () {
          if (mounted) setState(() => _stage = _Stage.verifying);
        },
      );
      _apk = f;
      if (!mounted) return;
      setState(() => _stage = _Stage.install);
      await UpdateService.install(f);
    } catch (e) {
      if (!mounted) return;
      final s = S.of(context);
      setState(() {
        _stage = _Stage.failed;
        _error = e is UpdateVerifyException ? s['upd_bad'] : '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = _p;
    final plan = _plan;
    final busy = _stage == _Stage.checking ||
        _stage == _Stage.downloading ||
        _stage == _Stage.verifying;
    final status = switch (_stage) {
      _Stage.checking => s['check_update'],
      _Stage.none => '${s['up_to_date']} (v$kAppVersion)',
      _Stage.ready => s.f('update_available', {'v': plan?.version ?? ''}),
      _Stage.downloading => s.f('update_available', {'v': plan?.version ?? ''}),
      _Stage.verifying => s['upd_verifying'],
      _Stage.install => s['install'],
      _Stage.failed => '${s['update_failed']}\n$_error',
    };
    return AlertDialog(
      title: Row(children: [
        Icon(Icons.system_update_alt_rounded, color: AppColors.rose),
        const SizedBox(width: 8),
        Expanded(child: Text(s['update'])),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status),
            if (_stage == _Stage.ready) ...[
              const SizedBox(height: 6),
              Text(s['upd_press'], style: Theme.of(context).textTheme.bodySmall),
            ],
            if (_fellBack) ...[
              const SizedBox(height: 6),
              Text(s['upd_fallback'], style: Theme.of(context).textTheme.bodySmall),
            ],
            if (p != null && _stage != _Stage.ready) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                    value: _stage == _Stage.verifying ? null : p.fraction, minHeight: 10),
              ),
              const SizedBox(height: 8),
              Text(
                '${p.percent}%  •  ${UpdateProgress.mb(p.received)} MB / ${UpdateProgress.mb(p.total)} MB',
                style: const TextStyle(fontWeight: FontWeight.w600),
                textDirection: TextDirection.ltr,
              ),
              Text(
                '${s.f('upd_remaining', {'n': UpdateProgress.mb(p.remaining)})}  •  '
                '${s.f('upd_speed', {'n': UpdateProgress.mb(p.speedBps)})}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(p.patchMode ? s['upd_patch'] : s['upd_full'],
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: p.patchMode ? FcLook.instance.palette['ok-text'] : AppColors.inkSoft)),
            ] else if (busy) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
            ],
            if (plan != null && plan.note(s.code).trim().isNotEmpty &&
                (_stage == _Stage.ready || _stage == _Stage.downloading)) ...[
              const SizedBox(height: 12),
              Text(plan.note(s.code).trim(),
                  style: Theme.of(context).textTheme.bodySmall, maxLines: 8),
            ],
            if (_stage == _Stage.none && kNews.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  showWhatsNew(context, force: true);
                },
                child: Text(s['wn_show']),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_stage == _Stage.ready) ...[
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s['upd_later'])),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
              onPressed: _go,
              child: Text(s['upd_now'])),
        ] else if (_stage == _Stage.install && _apk != null) ...[
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s['ok'])),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
              onPressed: () => UpdateService.install(_apk!),
              child: Text(s['upd_install_again'])),
        ] else if (!busy)
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s['ok']))
      ],
    );
  }
}

/// "Neler yeni": güncellemeden sonraki ilk açılışta bir kez (ya da istenince).
Future<void> showWhatsNew(BuildContext context, {bool force = false}) async {
  final st = Settings.instance;
  final seen = st.lastSeenVersion;
  if (!force) {
    st.lastSeenVersion = kAppVersion;
    // ilk kurulumda gösterilmez; yalnızca eski bir sürümden güncellenince
    if (seen == kAppVersion || !st.welcomed) return;
  }
  if (!context.mounted || kNews.isEmpty) return;
  final s = S.of(context);
  final n = kNews.first;
  final items = n.items[s.code] ?? n.items['en'] ?? const <String>[];
  await showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(s['wn_title']),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.f('wn_ver', {'v': n.v}),
                style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            if (items.isEmpty) Text(s['wn_none']),
            for (final i in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 7, color: AppColors.rose),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(i)),
                ]),
              ),
            const SizedBox(height: 4),
            Text(s['wn_safe'], style: Theme.of(c).textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(c),
            child: Text(s['ok'])),
      ],
    ),
  );
}
