import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/usage.dart';
import 'common.dart';

/// Ayarlar > Kullanım Limitleri kartı.
class UsageCard extends StatefulWidget {
  const UsageCard({super.key});

  @override
  State<UsageCard> createState() => _UsageCardState();
}

class _UsageCardState extends State<UsageCard> {
  late Future<Map<String, dynamic>> _f = Usage.load();

  String _num(Object? n) => '${n ?? 0}';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    return SoftCard(
      child: FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (context, snap) {
          final v = snap.data ?? const {};
          final left = Usage.untilReset();
          final dun = v['dun'];
          final raw = v['ai'] is Map ? v['ai'] as Map : const {};
          int n(String k) => (raw[k] as num?)?.toInt() ?? 0;
          final ai = {'Gemini': n('gemini'), 'OpenAI': n('openai'), 'Claude': n('claude')};
          Widget row(String a, String b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: Text(a)),
                  Text(b, style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✦ ${s['usage_ai']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (v['doldu'] == true)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.4))),
                  child: Text(s['usage_full'],
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                ),
              row(s['usage_requests'], _num(v['istek'])),
              row(s['usage_tokens'], _num(v['token'])),
              const SizedBox(height: 6),
              Text(s['usage_by_provider'], style: const TextStyle(fontWeight: FontWeight.w600)),
              if (ai.values.every((n) => n == 0))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(s['usage_no_ai'], style: small),
                )
              else
                for (final e in ai.entries) row(e.key, s.f('usage_calls', {'n': e.value})),
              if (dun is Map)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${s['usage_yesterday']}: ${s['usage_requests']} ${_num(dun['istek'])} · ${s['usage_tokens']} ${_num(dun['token'])}',
                      style: small),
                ),
              const SizedBox(height: 6),
              Text(s['usage_note'], style: small),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Text(
                      '⏱ ${s.f('usage_reset', {'h': left.inHours, 'm': left.inMinutes % 60})}'),
                ),
                IconButton(
                  tooltip: s['usage_refresh'],
                  onPressed: () => setState(() => _f = Usage.load()),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }
}
