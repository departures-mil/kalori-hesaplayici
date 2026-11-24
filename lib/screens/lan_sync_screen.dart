import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';
import '../services/lan_sync.dart';
import '../widgets/common.dart';

/// İnternetsiz (aynı modem) eşitleme ekranı.
class LanSyncScreen extends StatefulWidget {
  const LanSyncScreen({super.key});

  @override
  State<LanSyncScreen> createState() => _LanSyncScreenState();
}

class _LanSyncScreenState extends State<LanSyncScreen> {
  List<String> _ips = [];
  String? _pin;
  String _hostLog = '';
  StreamSubscription<String>? _sub;

  final _host = TextEditingController();
  final _code = TextEditingController();
  List<String> _found = [];
  double? _scan;
  bool _busy = false;
  String _result = '';

  @override
  void initState() {
    super.initState();
    LanSync.localIps().then((v) {
      if (mounted) setState(() => _ips = v);
    });
    _pin = LanSync.pin;
    _sub = LanSync.events.listen((e) {
      if (!mounted) return;
      final s = S.of(context);
      final p = e.split(':');
      setState(() => _hostLog = p.first == 'merged'
          ? s.f('lan_merged', {'a': p[1], 'u': p[2]})
          : s['lan_error']);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _host.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _toggleHost() async {
    if (LanSync.hosting) {
      await LanSync.stopHost();
      setState(() => _pin = null);
    } else {
      try {
        final p = await LanSync.startHost();
        setState(() => _pin = p);
      } catch (_) {
        if (mounted) showSnack(context, S.of(context)['lan_error']);
      }
    }
  }

  Future<void> _discover() async {
    setState(() {
      _scan = 0;
      _found = [];
    });
    final f = await LanSync.discover(progress: (v) {
      if (mounted) setState(() => _scan = v);
    });
    if (!mounted) return;
    setState(() {
      _scan = null;
      _found = f;
      if (f.length == 1) _host.text = f.first;
    });
    if (f.isEmpty) showSnack(context, S.of(context)['lan_none_found']);
  }

  Future<void> _sync() async {
    final s = S.of(context);
    if (_host.text.trim().isEmpty || _code.text.trim().length != 6) {
      showSnack(context, s['lan_need_both']);
      return;
    }
    setState(() {
      _busy = true;
      _result = '';
    });
    try {
      final r = await LanSync.syncWith(_host.text, _code.text);
      setState(() => _result =
          s.f('lan_merged', {'a': '${r['added']}', 'u': '${r['updated']}'}));
    } on LanSyncError catch (e) {
      setState(() => _result = e.code == 'pin' ? s['lan_bad_pin'] : s['lan_unreachable']);
    } catch (_) {
      setState(() => _result = s['lan_error']);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hosting = LanSync.hosting;
    return Scaffold(
      appBar: AppBar(title: Text(s['lan_title'])),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Text(s['lan_intro'], style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(height: 16),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['lan_host_title'],
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                SizedBox(height: 6),
                Text(s['lan_host_hint'], style: Theme.of(context).textTheme.bodySmall),
                SizedBox(height: 12),
                if (hosting && _pin != null) ...[
                  Text('${s['lan_address']}: ${_ips.isEmpty ? '—' : _ips.join(', ')}',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text('${s['lan_code']}: $_pin',
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w800,
                          letterSpacing: 4, color: AppColors.rose)),
                  if (_hostLog.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(_hostLog),
                  ],
                  SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: _toggleHost,
                  icon: Icon(hosting ? Icons.stop_rounded : Icons.wifi_tethering_rounded),
                  label: Text(hosting ? s['lan_stop'] : s['lan_start']),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['lan_join_title'],
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _scan != null ? null : _discover,
                  icon: Icon(Icons.radar_rounded),
                  label: Text(s['lan_find']),
                ),
                if (_scan != null) ...[
                  SizedBox(height: 8),
                  LinearProgressIndicator(value: _scan, color: AppColors.rose),
                ],
                if (_found.length > 1)
                  Wrap(spacing: 8, children: [
                    for (final f in _found)
                      ActionChip(label: Text(f), onPressed: () => setState(() => _host.text = f)),
                  ]),
                SizedBox(height: 10),
                TextField(
                  controller: _host,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s['lan_address']),
                ),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(labelText: s['lan_code']),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _sync,
                  icon: _busy
                      ? SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.sync_rounded),
                  label: Text(s['lan_sync_now']),
                ),
                if (_result.isNotEmpty) ...[
                  SizedBox(height: 10),
                  Text(_result, style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
