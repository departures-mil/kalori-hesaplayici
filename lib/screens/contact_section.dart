import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/fc_contact.dart';
import '../widgets/common.dart';

/// "Admin ile iletişim" (Ayarlar'ın EN SONU): ortak çekirdek gelen kutusu (FcContact, SPEC alanları).
/// Gönderilemezse mesaj sıraya alınır ve bağlantı gelince kendiliğinden gönderilir.
class ContactSection extends StatefulWidget {
  const ContactSection({super.key});

  @override
  State<ContactSection> createState() => _ContactSectionState();
}

class _ContactSectionState extends State<ContactSection> {
  final _reach = TextEditingController();
  final _msg = TextEditingController();
  String _type = 'oneri';
  String _status = '';
  bool _busy = false;
  int _waiting = 0;

  @override
  void initState() {
    super.initState();
    _count();
  }

  Future<void> _count() async {
    final n = (await FcContact.queue()).length;
    if (mounted) setState(() => _waiting = n);
  }

  @override
  void dispose() {
    _reach.dispose();
    _msg.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final s = S.of(context);
    final msg = _msg.text.trim();
    if (msg.isEmpty) return setState(() => _status = s['contact_empty']);
    setState(() {
      _busy = true;
      _status = s['contact_sending'];
    });
    try {
      final r = await FcContact.send(tur: _type, mesaj: msg, iletisim: _reach.text.trim());
      _msg.clear();
      if (mounted) setState(() => _status = r == 'sent' ? s['contact_ok'] : s['contact_queued']);
    } catch (_) {
      if (mounted) setState(() => _status = s['contact_fail']);
    } finally {
      if (mounted) setState(() => _busy = false);
      _count();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s['contact_desc'], style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'oneri', label: Text(s['contact_suggest']), icon: const Icon(Icons.lightbulb_outline_rounded, size: 18)),
              ButtonSegment(value: 'hata', label: Text(s['contact_bug']), icon: const Icon(Icons.bug_report_outlined, size: 18)),
            ],
            selected: {_type},
            onSelectionChanged: (v) => setState(() => _type = v.first),
          ),
          const SizedBox(height: 10),
          TextField(
              controller: _reach,
              maxLength: 160,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: s['contact_reach'], counterText: '')),
          const SizedBox(height: 8),
          TextField(
              controller: _msg,
              maxLength: 5000,
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(labelText: s['contact_msg'], counterText: '')),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(120, 46)),
              onPressed: _busy ? null : _send,
              icon: const Icon(Icons.mail_outline_rounded, size: 18),
              label: Text(s['contact_send']),
            ),
          ),
          if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_status)),
          if (_waiting > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(s.f('contact_waiting', {'n': _waiting}),
                  style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}
