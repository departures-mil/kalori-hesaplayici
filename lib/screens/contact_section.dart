import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../l10n/strings.dart';
import '../services/update_service.dart';
import '../widgets/common.dart';

/// "Admin ile iletişime geç": öneri / hata bildirimi doğrudan yöneticiye (FormSubmit) gider.
class ContactSection extends StatefulWidget {
  const ContactSection({super.key});

  @override
  State<ContactSection> createState() => _ContactSectionState();
}

class _ContactSectionState extends State<ContactSection> {
  final _name = TextEditingController();
  final _mail = TextEditingController();
  final _msg = TextEditingController();
  String _status = '';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _mail.dispose();
    _msg.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final s = S.of(context);
    final msg = _msg.text.trim();
    final mail = _mail.text.trim();
    if (msg.isEmpty) return setState(() => _status = s['contact_empty']);
    if (mail.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) {
      return setState(() => _status = s['contact_bad']);
    }
    setState(() {
      _busy = true;
      _status = s['contact_sending'];
    });
    try {
      final to = String.fromCharCodes(
          utf8.decode(base64.decode('')).codeUnits.reversed);
      String ver = '';
      try {
        ver = await UpdateService.currentVersion();
      } catch (_) {}
      final body = <String, String>{
        '_subject': 'Kalori Hesaplayıcı: yeni mesaj',
        '_template': 'table',
        '_captcha': 'false',
        'Ad': _name.text.trim().isEmpty ? '-' : _name.text.trim(),
        'Mesaj': msg,
        'Surum': ver,
        'Cihaz': Platform.operatingSystem,
        'Dil': s.code,
      };
      if (mail.isNotEmpty) {
        body['email'] = mail;
        body['_replyto'] = mail;
      }
      final r = await http
          .post(Uri.parse('https://formsubmit.co/ajax/$to'),
              headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      if (r.statusCode >= 300 && !r.body.toLowerCase().contains('activat')) {
        throw Exception('${r.statusCode}');
      }
      _msg.clear();
      if (mounted) setState(() => _status = s['contact_ok']);
    } catch (_) {
      if (mounted) setState(() => _status = s['contact_fail']);
    } finally {
      if (mounted) setState(() => _busy = false);
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
          TextField(controller: _name, maxLength: 80, decoration: InputDecoration(labelText: s['contact_name'], counterText: '')),
          const SizedBox(height: 8),
          TextField(
              controller: _mail,
              maxLength: 120,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: s['contact_mail'], counterText: '')),
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
              onPressed: _busy ? null : _send,
              icon: const Icon(Icons.mail_outline_rounded, size: 18),
              label: Text(s['contact_send']),
            ),
          ),
          if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_status)),
        ],
      ),
    );
  }
}
