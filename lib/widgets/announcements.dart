import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/settings.dart';
import '../services/update_service.dart';

/// Admin duyuruları (https://github.com/departures-mil/duyurular).
/// Yeni duyuru bir kez pencere olarak açılır; 🔔 düğmesi listeyi gösterir.
const _kaynak = 'https://raw.githubusercontent.com/departures-mil/duyurular/main/duyurular.json';
const _uygulama = 'kalori-hesaplayici';

const Map<String, Map<String, String>> _yazi = {
  'tr': {'baslik': 'Duyurular', 'tamam': 'Tamam', 'kapat': 'Kapat', 'yok': 'Henüz duyuru yok.', 'ac': 'Bağlantıyı aç', 'onemli': 'Önemli'},
  'en': {'baslik': 'Announcements', 'tamam': 'OK', 'kapat': 'Close', 'yok': 'No announcements yet.', 'ac': 'Open link', 'onemli': 'Important'},
  'ar': {'baslik': 'الإعلانات', 'tamam': 'حسناً', 'kapat': 'إغلاق', 'yok': 'لا توجد إعلانات بعد.', 'ac': 'فتح الرابط', 'onemli': 'مهم'},
};

class AnnouncementBell extends StatefulWidget {
  const AnnouncementBell({super.key});

  @override
  State<AnnouncementBell> createState() => _AnnouncementBellState();
}

class _AnnouncementBellState extends State<AnnouncementBell> {
  List<Map<String, dynamic>> _liste = [];
  List<String> _gorulen = [];
  String _surum = '0';
  Timer? _zaman;
  bool _acik = false;

  String get _dil {
    final d = Settings.instance.lang;
    return _yazi.containsKey(d) ? d : 'tr';
  }

  String _t(String k) => _yazi[_dil]![k]!;

  String _sec(dynamic o) {
    if (o == null) return '';
    if (o is String) return o;
    if (o is Map) return (o[_dil] ?? o['tr'] ?? o['en'] ?? o['ar'] ?? '').toString();
    return '';
  }

  @override
  void initState() {
    super.initState();
    _baslat();
  }

  @override
  void dispose() {
    _zaman?.cancel();
    super.dispose();
  }

  Future<void> _baslat() async {
    try {
      _surum = await UpdateService.currentVersion();
    } catch (_) {}
    final p = await SharedPreferences.getInstance();
    _gorulen = p.getStringList('duyuru_gorulen') ?? [];
    try {
      final o = p.getString('duyuru_onbellek');
      if (o != null) _isle(jsonDecode(o) as List, goster: false);
    } catch (_) {}
    await Future<void>.delayed(const Duration(seconds: 5));
    await _yenile();
    _zaman = Timer.periodic(const Duration(minutes: 30), (_) => _yenile());
  }

  Future<void> _yenile() async {
    try {
      final r = await http
          .get(Uri.parse('$_kaynak?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return;
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      final t = (j is Map ? j['duyurular'] : null) as List? ?? [];
      final p = await SharedPreferences.getInstance();
      await p.setString('duyuru_onbellek', jsonEncode(t));
      _isle(t);
    } catch (_) {}
  }

  static int _cmp(String a, String b) {
    List<int> f(String v) => v.replaceAll(RegExp(r'^[vV.]+'), '').split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final x = f(a), y = f(b);
    for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
      final p = i < x.length ? x[i] : 0, q = i < y.length ? y[i] : 0;
      if (p != q) return p < q ? -1 : 1;
    }
    return 0;
  }

  bool _uygun(Map<String, dynamic> d) {
    if (d['id'] == null || d['aktif'] == false) return false;
    final h = (d['hedef'] as List?)?.map((e) => e.toString()).toList() ?? ['*'];
    if (!h.contains('*') && !h.contains(_uygulama)) return false;
    final simdi = DateTime.now();
    final b = DateTime.tryParse('${d['baslangic'] ?? ''}');
    final s = DateTime.tryParse('${d['bitis'] ?? ''}');
    if (b != null && b.isAfter(simdi)) return false;
    if (s != null && s.isBefore(simdi)) return false;
    if (d['altSurum'] != null && _cmp(_surum, '${d['altSurum']}') < 0) return false;
    if (d['ustSurum'] != null && _cmp(_surum, '${d['ustSurum']}') > 0) return false;
    return true;
  }

  void _isle(List t, {bool goster = true}) {
    final l = t.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where(_uygun).toList()
      ..sort((a, b) => '${b['tarih']}'.compareTo('${a['tarih']}'));
    if (!mounted) return;
    setState(() => _liste = l);
    if (goster) _siradaki();
  }

  Future<void> _goruldu(String id) async {
    if (_gorulen.contains(id)) return;
    _gorulen.add(id);
    if (_gorulen.length > 300) _gorulen = _gorulen.sublist(_gorulen.length - 300);
    final p = await SharedPreferences.getInstance();
    await p.setStringList('duyuru_gorulen', _gorulen);
    if (mounted) setState(() {});
  }

  Widget _govde(Map<String, dynamic> d) {
    final tarih = DateTime.tryParse('${d['tarih']}')?.toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          if (d['onem'] == 'onemli')
            Container(
              margin: const EdgeInsetsDirectional.only(end: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
              child: Text(_t('onemli'), style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          Expanded(child: Text(_sec(d['baslik']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
        ]),
        if (tarih != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Text('${tarih.day.toString().padLeft(2, '0')}.${tarih.month.toString().padLeft(2, '0')}.${tarih.year}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        Text(_sec(d['metin'])),
        if (d['link'] != null)
          TextButton(
            onPressed: () => launchUrl(Uri.parse('${d['link']}'), mode: LaunchMode.externalApplication),
            child: Text(_t('ac')),
          ),
      ],
    );
  }

  Future<void> _siradaki() async {
    if (_acik || !mounted) return;
    final yeni = _liste.reversed.where((d) => !_gorulen.contains('${d['id']}')).toList();
    if (yeni.isEmpty) return;
    final d = yeni.first;
    _acik = true;
    await _goruldu('${d['id']}');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('🔔 ${_t('baslik')}'),
        content: SingleChildScrollView(child: _govde(d)),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(_t('tamam')))],
      ),
    );
    _acik = false;
    _siradaki();
  }

  Future<void> _listeyiGoster() async {
    for (final d in _liste) {
      await _goruldu('${d['id']}');
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('🔔 ${_t('baslik')}'),
        content: SizedBox(
          width: double.maxFinite,
          child: _liste.isEmpty
              ? Text(_t('yok'))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _liste.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, i) => _govde(_liste[i]),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(_t('kapat')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_liste.isEmpty) return const SizedBox.shrink();
    final yeni = _liste.where((d) => !_gorulen.contains('${d['id']}')).length;
    return IconButton(
      tooltip: _t('baslik'),
      onPressed: _listeyiGoster,
      icon: Badge(
        isLabelVisible: yeni > 0,
        label: Text('$yeni'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
