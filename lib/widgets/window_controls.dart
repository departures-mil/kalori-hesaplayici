import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';
import '../services/sync_service.dart';
import '../services/update_service.dart';
import 'common.dart';

const _channel = MethodChannel('kalori/window');

/// Top-right buttons: update, sync, minimize, close.
class WindowControls extends StatefulWidget {
  const WindowControls({super.key});

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> {
  bool _syncing = false;
  bool _updateAvailable = false;

  @override
  void initState() {
    super.initState();
    _silentCheck();
  }

  Future<void> _silentCheck() async {
    try {
      final u = await UpdateService.check();
      if (mounted) setState(() => _updateAvailable = u != null);
    } catch (_) {}
  }

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
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(s['no'])),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(s['yes'])),
        ],
      ),
    );
    if (ok == true) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(
          icon: Icons.system_update_alt_rounded,
          tip: s['update'],
          badge: _updateAvailable,
          onTap: () => showUpdateDialog(context).then((_) => _silentCheck()),
        ),
        _btn(
          icon: Icons.sync_rounded,
          tip: s['sync'],
          busy: _syncing,
          onTap: _syncing ? null : _sync,
        ),
        _btn(icon: Icons.remove_rounded, tip: s['minimize'], onTap: _minimize),
        _btn(icon: Icons.close_rounded, tip: s['close'], onTap: _close),
        const SizedBox(width: 6),
      ],
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
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(icon, size: 22, color: AppColors.ink),
                if (badge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                          color: AppColors.rose, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

/// Full update flow: check → download (percent, MB, speed) → install.
Future<void> showUpdateDialog(BuildContext context) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _UpdateDialog(),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog();

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  String _status = '';
  UpdateInfo? _info;
  DownloadProgress? _progress;
  bool _done = false;
  bool _failed = false;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final s = S.of(context);
    setState(() => _status = s['check_update']);
    try {
      final info = await UpdateService.check();
      if (!mounted) return;
      if (info == null) {
        setState(() {
          _status = s['up_to_date'];
          _busy = false;
          _done = true;
        });
        return;
      }
      setState(() {
        _info = info;
        _status = s.f('update_available', {'v': info.version});
      });
      final file = await UpdateService.download(info, (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
        _status = s['install'];
      });
      await UpdateService.install(file);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = true;
        _status = '${s['update_failed']}\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = _progress;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.system_update_alt_rounded, color: AppColors.rose),
        const SizedBox(width: 8),
        Text(s['update']),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_status),
          if (p != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                  value: p.fraction, minHeight: 10, color: AppColors.rose),
            ),
            const SizedBox(height: 8),
            Text(
              '${(p.fraction * 100).toStringAsFixed(0)}%  •  '
              '${DownloadProgress.mb(p.received)} / ${DownloadProgress.mb(p.total)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${s['remaining']}: ${DownloadProgress.mb(p.remaining)}  •  ${p.speedText}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (_busy) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(color: AppColors.rose),
          ],
          if (_info != null && _info!.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_info!.notes.trim(),
                style: Theme.of(context).textTheme.bodySmall, maxLines: 6),
          ],
        ],
      ),
      actions: [
        if (!_busy || _failed)
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_done ? s['ok'] : s['cancel'])),
      ],
    );
  }
}
